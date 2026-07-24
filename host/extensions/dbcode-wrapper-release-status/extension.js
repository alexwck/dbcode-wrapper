'use strict';

const https = require('node:https');
const path = require('node:path');
const vscode = require('vscode');
const {
  CODE_OSS_METADATA_URL,
  DBCODE_METADATA_URL,
  VSCODIUM_METADATA_URL,
  createReleaseStatusService
} = require('./release-status');

const STATE_FILENAME = 'release-status-state.json';
const INSTALLED_RELEASE_FILENAME = 'installed-release-set.json';
const APPROVED_RELEASES_FILENAME = 'approved-release-sets.json';
const APPLY_UPDATE_STATUS_COMMAND = 'dbcodeWrapper.applyUpdateStatus';
const MAX_RESPONSE_BYTES = 2 * 1024 * 1024;
const REQUEST_TIMEOUT_MS = 10_000;
const QA_RELEASE_LINK_CAPTURE_ENV = 'DBCODE_WRAPPER_QA_CAPTURE_RELEASE_LINKS';
const QA_RELEASE_LINK_CAPTURE_FILENAME = 'rendered-release-link-capture.jsonl';
const OFFICIAL_METADATA_URLS = new Set([
  VSCODIUM_METADATA_URL,
  CODE_OSS_METADATA_URL,
  DBCODE_METADATA_URL
]);

function decodeJson(bytes, label) {
  try {
    return JSON.parse(Buffer.from(bytes).toString('utf8'));
  } catch {
    throw new Error(`${label} is not valid JSON.`);
  }
}

async function readJson(uri, label, fallback) {
  try {
    return decodeJson(await vscode.workspace.fs.readFile(uri), label);
  } catch (error) {
    if (fallback !== undefined) {
      return fallback;
    }
    throw error;
  }
}

function fetchJson(url) {
  if (!OFFICIAL_METADATA_URLS.has(url)) {
    return Promise.reject(new Error('Refusing a non-official update metadata URL.'));
  }
  return new Promise((resolve, reject) => {
    const request = https.get(url, {
      headers: {
        Accept: 'application/json',
        'User-Agent': 'DBCode-Wrapper-Update-Check'
      }
    }, response => {
      if (response.statusCode !== 200) {
        response.resume();
        reject(new Error(`Metadata request returned HTTP ${response.statusCode}.`));
        return;
      }
      const chunks = [];
      let length = 0;
      response.on('data', chunk => {
        length += chunk.length;
        if (length > MAX_RESPONSE_BYTES) {
          request.destroy(new Error('Metadata response is too large.'));
          return;
        }
        chunks.push(chunk);
      });
      response.on('end', () => {
        try {
          resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
        } catch {
          reject(new Error('Metadata response is not valid JSON.'));
        }
      });
    });
    request.setTimeout(REQUEST_TIMEOUT_MS, () => request.destroy(new Error('Metadata request timed out.')));
    request.on('error', reject);
  });
}

function formatDate(value) {
  const date = new Date(value);
  return Number.isFinite(date.getTime())
    ? new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(date)
    : 'Unknown date';
}

function updateItem(label, icon, release, explanation) {
  const versionChange = release.updateAvailable
    ? `${release.installedVersion} → ${release.availableVersion}`
    : `${release.installedVersion} (current)`;
  return {
    label: `$(${icon}) ${label}`,
    description: `${versionChange} · ${release.readiness}`,
    detail: release.updateAvailable
      ? `Installed ${formatDate(release.installedPublishedAt)} · Available ${formatDate(release.availablePublishedAt)} · ${explanation} · Open official release notes`
      : `Published ${formatDate(release.installedPublishedAt)} · ${explanation} · Open official release notes`,
    releaseNotesUrl: release.availableReleaseNotesUrl
  };
}

async function openReleaseNotes(context, releaseNotesUrl) {
  const globalStoragePath = path.resolve(context.globalStorageUri.fsPath);
  const qaPathSegment = `${path.sep}.build${path.sep}qa${path.sep}`;
  if (process.env[QA_RELEASE_LINK_CAPTURE_ENV] === '1' && globalStoragePath.includes(qaPathSegment)) {
    await vscode.workspace.fs.createDirectory(context.globalStorageUri);
    const captureUri = vscode.Uri.joinPath(context.globalStorageUri, QA_RELEASE_LINK_CAPTURE_FILENAME);
    let previous = Buffer.alloc(0);
    try {
      previous = await vscode.workspace.fs.readFile(captureUri);
    } catch {
      // The first captured link creates the file.
    }
    await vscode.workspace.fs.writeFile(
      captureUri,
      Buffer.concat([previous, Buffer.from(`${releaseNotesUrl}\n`, 'utf8')])
    );
    return;
  }
  await vscode.env.openExternal(vscode.Uri.parse(releaseNotesUrl));
}

async function activate(context) {
  const installed = await readJson(
    vscode.Uri.joinPath(context.extensionUri, INSTALLED_RELEASE_FILENAME),
    'The installed release-set identity'
  );
  const bundledApprovedHistory = await readJson(
    vscode.Uri.joinPath(context.extensionUri, APPROVED_RELEASES_FILENAME),
    'The approved release-set history'
  );
  const stateUri = vscode.Uri.joinPath(context.globalStorageUri, STATE_FILENAME);
  const localApprovedHistoryUri = vscode.Uri.joinPath(context.globalStorageUri, APPROVED_RELEASES_FILENAME);
  let writeQueue = Promise.resolve();

  const loadState = () => readJson(stateUri, 'The update-status state', {});
  const loadApprovedReleaseSets = async () => {
    const localApprovedHistory = await readJson(localApprovedHistoryUri, 'The local approved release-set history', {
      schema_version: 2,
      approved_release_sets: []
    });
    return {
      schema_version: 2,
      approved_release_sets: [
        ...(Array.isArray(bundledApprovedHistory.approved_release_sets) ? bundledApprovedHistory.approved_release_sets : []),
        ...(Array.isArray(localApprovedHistory.approved_release_sets) ? localApprovedHistory.approved_release_sets : [])
      ]
    };
  };
  const saveState = state => {
    writeQueue = writeQueue.catch(() => undefined).then(async () => {
      await vscode.workspace.fs.createDirectory(context.globalStorageUri);
      const temporaryUri = vscode.Uri.joinPath(context.globalStorageUri, `${STATE_FILENAME}.tmp`);
      const contents = Buffer.from(`${JSON.stringify(state, null, 2)}\n`, 'utf8');
      await vscode.workspace.fs.writeFile(temporaryUri, contents);
      await vscode.workspace.fs.rename(temporaryUri, stateUri, { overwrite: true });
    });
    return writeQueue;
  };

  const service = createReleaseStatusService({
    installed,
    loadApprovedReleaseSets,
    loadState,
    saveState,
    fetchJson
  });
  let currentStatus;
  let currentCheck;

  const reviewStatus = async status => {
    if (status.kind === 'offline') {
      const choice = await vscode.window.showWarningMessage(
        'DBCode Wrapper could not reach the official update services. The installed release is unchanged.',
        'Check Again'
      );
      if (choice === 'Check Again') {
        await checkAndReview(true);
      }
      return;
    }
    if (status.kind === 'invalid') {
      await vscode.window.showWarningMessage('DBCode Wrapper received invalid update metadata. The installed release is unchanged.');
      return;
    }
    const selection = await vscode.window.showQuickPick([
      updateItem('Code OSS runtime', 'code', status.codeOss, 'Defines the editor runtime and requires a new tested DBCode Wrapper build'),
      updateItem('VSCodium packaging', 'package', status.vscodium, 'Supplies the macOS packaging; DBCode Wrapper is never replaced with stock VSCodium'),
      updateItem('DBCode', 'database', status.dbcode, 'Must be tested with the runtime and packaging and is never installed alone')
    ], {
      title: !status.updatesAvailable
        ? 'DBCode Wrapper is current'
        : status.readyToInstall
          ? 'Approved Release Set ready to install'
          : 'Updates found — exact release set not tested',
      placeHolder: 'Choose a component to open its official release notes',
      matchOnDescription: true,
      matchOnDetail: true
    });
    if (selection?.releaseNotesUrl) {
      await openReleaseNotes(context, selection.releaseNotesUrl);
    }
  };

  const maybePrompt = async status => {
    if (!status.shouldPrompt) {
      return;
    }
    await service.markPrompted(status);
    const readiness = status.readyToInstall ? 'This exact release set passed local approval.' : 'This exact release set is not tested.';
    const choice = await vscode.window.showInformationMessage(
      `A Code OSS runtime, VSCodium packaging, or DBCode update is available. ${readiness} DBCode Wrapper never installs updates automatically.`,
      'Review',
      'Remind Later',
      'Skip This Version'
    );
    if (choice === 'Review') {
      await service.decide('review', status);
      await reviewStatus(status);
    } else if (choice === 'Remind Later') {
      await service.decide('remind', status);
    } else if (choice === 'Skip This Version') {
      await service.decide('skip', status);
    }
  };

  const publishStatus = async status => {
    currentStatus = status;
    await vscode.commands.executeCommand(APPLY_UPDATE_STATUS_COMMAND, status).then(undefined, () => undefined);
    return status;
  };

  const startCheck = force => {
    currentCheck = service.check({ force }).then(publishStatus).finally(() => {
      currentCheck = undefined;
    });
    return currentCheck;
  };

  const getStatus = async (force, prompt) => {
    let status;
    if (currentCheck) {
      status = await currentCheck;
      if (force) {
        status = await startCheck(true);
      }
    } else {
      status = await startCheck(force);
    }
    if (prompt) {
      void maybePrompt(status).catch(error => console.error('DBCode Wrapper could not save the update-notification state.', error));
    }
    return status;
  };

  async function checkAndReview(force) {
    const status = await getStatus(force, false);
    await reviewStatus(status);
    return status;
  }

  context.subscriptions.push(
    vscode.commands.registerCommand('dbcodeWrapper.getUpdateStatus', () => getStatus(false, true)),
    vscode.commands.registerCommand('dbcodeWrapper.reviewUpdates', async () => reviewStatus(currentStatus ?? await getStatus(false, false))),
    vscode.commands.registerCommand('dbcodeWrapper.checkForUpdates', () => checkAndReview(true))
  );
}

function deactivate() {}

module.exports = {
  activate,
  deactivate
};
