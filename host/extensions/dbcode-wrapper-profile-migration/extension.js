'use strict';

const fs = require('node:fs/promises');
const crypto = require('node:crypto');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');
const vscode = require('vscode');
const { deriveRecoveryLayout } = require('./profileRecovery');
const { PROFILE_SETUP_STATE_KEY, ProfileSetup } = require('./profileSetup');
const { cleanupReviewedInventory, stageReviewedInventory } = require('./staging');
const { renderProfileSetupHtml } = require('./view');
const {
  RuntimeSetupController,
  loadRuntimeConfiguration
} = require('./runtimeSetupController');

const START_MIGRATION_COMMAND = 'dbcodeWrapper.startProfileMigration';
const START_RUNTIME_SETUP_COMMAND = 'dbcodeWrapper.startRuntimeSetup';
const DBCODE_IMPORT_COMMAND = 'dbcode.connections.import';
const MAX_INVENTORY_BYTES = 2 * 1024 * 1024;

function profileUserDataRoot(context) {
  const extensionStorage = path.resolve(context.globalStorageUri.fsPath);
  const globalStorage = path.dirname(extensionStorage);
  const userDirectory = path.dirname(globalStorage);
  if (path.basename(globalStorage) !== 'globalStorage' || path.basename(userDirectory) !== 'User') {
    throw new Error('Profile recovery could not identify the Standalone DBCode Profile safely.');
  }
  return path.dirname(userDirectory);
}

function recoveryLayout(context) {
  return deriveRecoveryLayout({
    userDataRoot: profileUserDataRoot(context),
    homeDirectory: os.homedir(),
    appRoot: vscode.env.appRoot,
    environment: process.env
  });
}

function createProfileSetupController(context) {
  let panel;
  const stagingRoot = path.join(context.globalStorageUri.fsPath, 'profile-migration-staging');
  const setup = new ProfileSetup({
    loadState: async () => context.globalState.get(PROFILE_SETUP_STATE_KEY),
    saveState: state => context.globalState.update(PROFILE_SETUP_STATE_KEY, state),
    now: () => new Date(),
    randomUUID: () => crypto.randomUUID(),
    render: view => {
      if (panel) {
        panel.webview.html = renderProfileSetupHtml(view);
      }
    },
    chooseInventory: async () => {
      const selected = await vscode.window.showOpenDialog({
        title: 'Choose a connection inventory to review',
        openLabel: 'Review Connections',
        canSelectFiles: true,
        canSelectFolders: false,
        canSelectMany: false,
        filters: { 'Connection inventories': ['json', 'csv'] }
      });
      if (!selected?.[0]) {
        return undefined;
      }
      const source = selected[0];
      const metadata = await vscode.workspace.fs.stat(source);
      if (metadata.size > MAX_INVENTORY_BYTES) {
        throw new Error('The selected inventory is larger than the 2 MB review limit.');
      }
      return {
        contents: Buffer.from(await vscode.workspace.fs.readFile(source)).toString('utf8'),
        format: path.extname(source.fsPath).toLowerCase().slice(1)
      };
    },
    stageInventory: connections => stageReviewedInventory(stagingRoot, connections),
    cleanupInventory: staged => cleanupReviewedInventory(stagingRoot, staged.sessionDirectory),
    dbcodeVersion: () => vscode.extensions.getExtension('dbcode.dbcode')?.packageJSON?.version ?? 'the installed version',
    openDbcodeImport: async () => {
      const dbcode = vscode.extensions.getExtension('dbcode.dbcode');
      if (!dbcode) {
        throw new Error('The approved DBCode extension is not installed in this profile.');
      }
      await dbcode.activate();
      await vscode.commands.executeCommand(DBCODE_IMPORT_COMMAND);
    },
    revealPanel: () => panel?.reveal(vscode.ViewColumn.Active),
    copyText: value => vscode.env.clipboard.writeText(value),
    showInfo: message => vscode.window.showInformationMessage(message),
    showError: message => vscode.window.showErrorMessage(message),
    focusConnections: () => vscode.commands.executeCommand('dbcode.connections.view.focus'),
    closePanel: () => panel?.dispose(),
    confirmRecovery: async () => {
      const accepted = await vscode.window.showWarningMessage(
        'Back up and recreate the Standalone DBCode Profile?',
        {
          modal: true,
          detail: 'DBCode Wrapper will quit, move only its user and shared profile data into an owner-only backup, then reopen with a clean profile. Normal VS Code, Keychain records, verified extensions, and database files are not changed.'
        },
        'Back Up and Recreate Profile'
      );
      return accepted === 'Back Up and Recreate Profile';
    },
    recoveryContext: () => ({
      layout: recoveryLayout(context),
      processPids: [process.ppid, process.pid],
      relaunchArguments: process.env.DBCODE_WRAPPER_RECOVERY_RELAUNCH_ARGS,
      settingsSource: path.join(__dirname, 'managed-settings.json')
    }),
    startRecovery: request => {
      const workerPath = path.join(__dirname, 'profileRecoveryWorker.js');
      const worker = spawn(process.execPath, [workerPath, JSON.stringify(request)], {
        detached: true,
        stdio: 'ignore',
        env: { ...process.env, ELECTRON_RUN_AS_NODE: '1' }
      });
      return new Promise((resolve, reject) => {
        worker.once('spawn', () => {
          worker.unref();
          resolve();
        });
        worker.once('error', error => {
          reject(new Error(`Profile recovery could not start. ${error.message}`));
        });
      });
    },
    quit: () => vscode.commands.executeCommand('workbench.action.quit')
  });

  return {
    open() {
      if (panel) {
        panel.reveal(vscode.ViewColumn.Active);
        return;
      }
      panel = vscode.window.createWebviewPanel(
        'dbcodeWrapper.profileMigration',
        'Profile Setup',
        vscode.ViewColumn.Active,
        { enableScripts: true, retainContextWhenHidden: false }
      );
      panel.webview.onDidReceiveMessage(
        message => setup.dispatch(message?.action),
        undefined,
        context.subscriptions
      );
      panel.onDidDispose(() => {
        panel = undefined;
        void setup.panelClosed().catch(() => {
          void vscode.window.showErrorMessage('Profile Setup could not remove its temporary reviewed file.');
        });
      }, undefined, context.subscriptions);
      void setup.open();
    },
    requiresSetup: () => setup.requiresSetup()
  };
}

async function activate(context) {
  await fs.mkdir(context.globalStorageUri.fsPath, { recursive: true, mode: 0o700 });
  await fs.chmod(context.globalStorageUri.fsPath, 0o700);
  let runtimeConfiguration;
  try {
    runtimeConfiguration = await loadRuntimeConfiguration(context.extensionPath);
  } catch {
    void vscode.window.showErrorMessage('DBCode Wrapper cannot verify its focused first-run setup configuration. The external runtime was not changed.');
    return;
  }
  const runtimeSetup = new RuntimeSetupController({
    context,
    vscode,
    layout: recoveryLayout(context),
    configuration: runtimeConfiguration
  });
  context.subscriptions.push(vscode.commands.registerCommand(
    START_RUNTIME_SETUP_COMMAND,
    () => runtimeSetup.open()
  ));
  if (runtimeSetup.requiresSetup()) {
    const startupTimer = setTimeout(() => runtimeSetup.open(), 1200);
    context.subscriptions.push({ dispose: () => clearTimeout(startupTimer) });
    return;
  }

  const controller = createProfileSetupController(context);
  context.subscriptions.push(vscode.commands.registerCommand(START_MIGRATION_COMMAND, () => controller.open()));

  try {
    const { backupRoot } = recoveryLayout(context);
    const recoveryOutcomePath = path.join(backupRoot, 'last-recovery.json');
    const outcomeMetadata = await fs.lstat(recoveryOutcomePath);
    if (outcomeMetadata.isSymbolicLink() || !outcomeMetadata.isFile() || outcomeMetadata.size > 64 * 1024) {
      throw new Error('Profile recovery status is not a safe regular file.');
    }
    const outcome = JSON.parse(await fs.readFile(recoveryOutcomePath, 'utf8'));
    await fs.unlink(recoveryOutcomePath);
    if (outcome.status === 'complete') {
      void vscode.window.showInformationMessage(`A clean Standalone DBCode Profile was created. The previous profile is backed up at ${outcome.backupDirectory}.`);
    } else if (outcome.status === 'failed') {
      void vscode.window.showErrorMessage(`Standalone DBCode Profile recreation failed. ${outcome.message}`);
    }
  } catch (error) {
    if (error?.code !== 'ENOENT') {
      void vscode.window.showErrorMessage('Profile recovery status could not be read. The existing profile was not changed by this check.');
    }
  }
  if (await controller.requiresSetup()) {
    const startupTimer = setTimeout(() => controller.open(), 1200);
    context.subscriptions.push({ dispose: () => clearTimeout(startupTimer) });
  }
}

module.exports = { activate };
