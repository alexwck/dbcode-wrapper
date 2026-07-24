'use strict';

const fs = require('node:fs/promises');
const crypto = require('node:crypto');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');
const vscode = require('vscode');
const { advancePreflight, createMigrationPlan, parseInventory } = require('./migration');
const { deriveRecoveryLayout, requireMatchingRelaunchPath } = require('./profileRecovery');
const { cleanupReviewedInventory, stageReviewedInventory } = require('./staging');
const { renderProfileSetupHtml } = require('./view');
const {
  RuntimeSetupController,
  loadRuntimeConfiguration
} = require('./runtimeSetupController');

const START_MIGRATION_COMMAND = 'dbcodeWrapper.startProfileMigration';
const START_RUNTIME_SETUP_COMMAND = 'dbcodeWrapper.startRuntimeSetup';
const DBCODE_IMPORT_COMMAND = 'dbcode.connections.import';
const PROFILE_SETUP_STATE_KEY = 'dbcodeWrapper.profileSetup.v1';
const MAX_INVENTORY_BYTES = 2 * 1024 * 1024;
const MAX_CONNECTIONS = 500;

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

class ProfileMigrationController {
  constructor(context) {
    this.context = context;
    this.panel = undefined;
    this.plan = undefined;
    this.staged = undefined;
    this.preflightProgress = { completed: 0, deferred: [] };
    this.closingCleanly = false;
    this.stagingRoot = path.join(context.globalStorageUri.fsPath, 'profile-migration-staging');
  }

  open() {
    if (this.panel) {
      this.panel.reveal(vscode.ViewColumn.Active);
      return;
    }
    this.closingCleanly = false;
    this.panel = vscode.window.createWebviewPanel('dbcodeWrapper.profileMigration', 'Profile Setup', vscode.ViewColumn.Active, { enableScripts: true, retainContextWhenHidden: false });
    this.panel.webview.html = renderProfileSetupHtml({ kind: 'welcome' });
    this.panel.webview.onDidReceiveMessage(message => this.handleMessage(message).catch(error => this.showFailure(error)), undefined, this.context.subscriptions);
    this.panel.onDidDispose(() => {
      const staged = this.staged;
      this.panel = undefined;
      this.plan = undefined;
      this.staged = undefined;
      this.preflightProgress = { completed: 0, deferred: [] };
      if (!this.closingCleanly && staged) {
        void cleanupReviewedInventory(this.stagingRoot, staged.sessionDirectory).catch(() => undefined);
      }
    }, undefined, this.context.subscriptions);
  }

  render(view) {
    if (this.panel) {
      this.panel.webview.html = renderProfileSetupHtml(view);
    }
  }

  async chooseFile() {
    const selected = await vscode.window.showOpenDialog({
      title: 'Choose a connection inventory to review',
      openLabel: 'Review Connections',
      canSelectFiles: true,
      canSelectFolders: false,
      canSelectMany: false,
      filters: { 'Connection inventories': ['json', 'csv'] }
    });
    if (!selected?.[0]) {
      return;
    }
    const source = selected[0];
    const metadata = await vscode.workspace.fs.stat(source);
    if (metadata.size > MAX_INVENTORY_BYTES) {
      throw new Error('The selected inventory is larger than the 2 MB review limit.');
    }
    const format = path.extname(source.fsPath).toLowerCase().slice(1);
    const connections = parseInventory(Buffer.from(await vscode.workspace.fs.readFile(source)).toString('utf8'), format);
    if (connections.length === 0 || connections.length > MAX_CONNECTIONS) {
      throw new Error('The inventory must contain between 1 and 500 connections.');
    }
    await this.cleanupStaged();
    this.plan = createMigrationPlan(connections);
    this.preflightProgress = { completed: 0, deferred: [] };
    this.render({ kind: 'preview', plan: this.plan });
  }

  async confirmReview() {
    if (!this.plan) {
      return;
    }
    await this.cleanupStaged();
    if (this.plan.ready.length > 0) {
      this.staged = await stageReviewedInventory(this.stagingRoot, this.plan.ready);
      this.render({ kind: 'import', inventoryPath: this.staged.inventoryPath });
    } else {
      await this.showPreflight();
    }
  }

  async openImport() {
    if (!this.staged) {
      return;
    }
    const dbcode = vscode.extensions.getExtension('dbcode.dbcode');
    if (!dbcode) {
      throw new Error('The approved DBCode extension is not installed in this profile.');
    }
    await dbcode.activate();
    await vscode.commands.executeCommand(DBCODE_IMPORT_COMMAND);
    this.panel?.reveal(vscode.ViewColumn.Active);
    this.render({ kind: 'confirm-import' });
  }

  async copyPath() {
    if (this.staged) {
      await vscode.env.clipboard.writeText(this.staged.inventoryPath);
      await vscode.window.showInformationMessage('The reviewed temporary file path was copied.');
      this.render({ kind: 'import', inventoryPath: this.staged.inventoryPath });
    }
  }

  async cleanupStaged() {
    if (this.staged) {
      await cleanupReviewedInventory(this.stagingRoot, this.staged.sessionDirectory);
      this.staged = undefined;
    }
  }

  async finishImport() {
    await this.cleanupStaged();
    if (this.plan?.preflight.length) {
      await this.showPreflight();
    } else {
      await this.complete('imported', 0, 'Reviewed connection details were handed to DBCode. Re-enter protected credentials when DBCode asks.');
    }
  }

  async showPreflight() {
    const item = this.plan?.preflight[this.preflightProgress.completed];
    if (!item) {
      throw new Error('There is no pending DuckDB preflight connection.');
    }
    const dbcodeVersion = vscode.extensions.getExtension('dbcode.dbcode')?.packageJSON?.version ?? 'the installed version';
    this.render({
      kind: 'preflight',
      dbcodeVersion,
      connection: item.connection,
      position: this.preflightProgress.completed + 1,
      total: this.plan.preflight.length
    });
  }

  async finishPreflight(outcome) {
    this.preflightProgress = advancePreflight(this.plan?.preflight ?? [], this.preflightProgress, outcome);
    if (this.preflightProgress.completed < (this.plan?.preflight.length ?? 0)) {
      await this.showPreflight();
      return;
    }
    const deferredCount = this.preflightProgress.deferred.length;
    if (deferredCount > 0) {
      const deferredSummary = deferredCount === 1
        ? '1 DuckDB connection remains deferred without changing its file.'
        : `${deferredCount} DuckDB connections remain deferred without changing their files.`;
      await this.complete(
        'imported-with-deferred',
        deferredCount,
        `Profile setup is complete. ${deferredSummary}`
      );
    } else {
      await this.complete('imported-with-preflight', 0, 'Profile setup is complete and every conditional DuckDB preflight passed.');
    }
  }

  async complete(mode, deferredCount, message) {
    await this.cleanupStaged();
    await this.context.globalState.update(PROFILE_SETUP_STATE_KEY, {
      schemaVersion: 1,
      status: 'complete',
      mode,
      deferredConnectionCount: deferredCount,
      completedAt: new Date().toISOString()
    });
    this.render({ kind: 'complete', message });
  }

  async cancel() {
    await this.cleanupStaged();
    this.plan = undefined;
    this.preflightProgress = { completed: 0, deferred: [] };
    this.render({ kind: 'welcome' });
  }

  async close() {
    await this.cleanupStaged();
    this.closingCleanly = true;
    this.panel?.dispose();
  }

  recoveryRequest() {
    const layout = recoveryLayout(this.context);
    let relaunchArgs = [];
    if (process.env.DBCODE_WRAPPER_RECOVERY_RELAUNCH_ARGS) {
      try {
        relaunchArgs = JSON.parse(process.env.DBCODE_WRAPPER_RECOVERY_RELAUNCH_ARGS);
      } catch {
        throw new Error('Profile recovery received invalid relaunch arguments.');
      }
      if (!Array.isArray(relaunchArgs) || relaunchArgs.some(argument => typeof argument !== 'string')) {
        throw new Error('Profile recovery received invalid relaunch arguments.');
      }
    }
    requireMatchingRelaunchPath(relaunchArgs, '--user-data-dir', layout.userDataRoot);
    requireMatchingRelaunchPath(relaunchArgs, '--extensions-dir', layout.extensionsRoot);
    requireMatchingRelaunchPath(relaunchArgs, '--shared-data-dir', layout.sharedDataRoot);
    requireMatchingRelaunchPath(relaunchArgs, '--disk-cache-dir', layout.cacheRoot);
    requireMatchingRelaunchPath(relaunchArgs, '--logsPath', layout.logsRoot);
    const recoveryId = `${new Date().toISOString().replaceAll(/[-:.]/g, '')}-${crypto.randomUUID()}`;
    return {
      processPids: [...new Set([process.ppid, process.pid])],
      recoveryId,
      profileLayout: layout.profileLayout,
      userDataRoot: layout.userDataRoot,
      sharedDataRoot: layout.sharedDataRoot,
      backupRoot: layout.backupRoot,
      settingsSource: path.join(__dirname, 'managed-settings.json'),
      appBundle: layout.appBundle,
      relaunchArgs,
      relaunchApplication: true
    };
  }

  async recreateProfile() {
    const accepted = await vscode.window.showWarningMessage(
      'Back up and recreate the Standalone DBCode Profile?',
      {
        modal: true,
        detail: 'DBCode Wrapper will quit, move only its user and shared profile data into an owner-only backup, then reopen with a clean profile. Normal VS Code, Keychain records, verified extensions, and database files are not changed.'
      },
      'Back Up and Recreate Profile'
    );
    if (accepted !== 'Back Up and Recreate Profile') {
      return;
    }
    await this.cleanupStaged();
    const workerPath = path.join(__dirname, 'profileRecoveryWorker.js');
    const worker = spawn(process.execPath, [workerPath, JSON.stringify(this.recoveryRequest())], {
      detached: true,
      stdio: 'ignore',
      env: { ...process.env, ELECTRON_RUN_AS_NODE: '1' }
    });
    await new Promise((resolve, reject) => {
      worker.once('spawn', resolve);
      worker.once('error', reject);
    }).catch(error => {
      throw new Error(`Profile recovery could not start. ${error.message}`);
    });
    worker.unref();
    await vscode.commands.executeCommand('workbench.action.quit');
  }

  async handleMessage(message) {
    switch (message?.action) {
      case 'choose-file': return this.chooseFile();
      case 'confirm-review': return this.confirmReview();
      case 'open-import': return this.openImport();
      case 'copy-path': return this.copyPath();
      case 'finish-import': return this.finishImport();
      case 'cancel': return this.cancel();
      case 'start-fresh': return this.complete('fresh', 0, 'A Standalone DBCode Profile is ready. Add connections and activate DBCode normally.');
      case 'preflight-passed': return this.finishPreflight('passed');
      case 'keep-deferred': return this.finishPreflight('deferred');
      case 'open-connections': await vscode.commands.executeCommand('dbcode.connections.view.focus'); return this.close();
      case 'later': return this.close();
      case 'close': return this.close();
      case 'recreate-profile': return this.recreateProfile();
    }
  }

  async showFailure(error) {
    const message = error instanceof Error ? error.message : 'Profile setup could not continue.';
    await vscode.window.showErrorMessage(`This connection inventory was not accepted. ${message}`);
    if (this.staged) {
      this.render({ kind: 'import', inventoryPath: this.staged.inventoryPath });
    } else if (this.plan) {
      this.render({ kind: 'preview', plan: this.plan });
    } else {
      this.render({ kind: 'welcome' });
    }
  }
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

  const controller = new ProfileMigrationController(context);
  context.subscriptions.push(vscode.commands.registerCommand(START_MIGRATION_COMMAND, () => controller.open()));

  const state = context.globalState.get(PROFILE_SETUP_STATE_KEY);
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
  if (state?.schemaVersion !== 1 || state.status !== 'complete') {
    const startupTimer = setTimeout(() => controller.open(), 1200);
    context.subscriptions.push({ dispose: () => clearTimeout(startupTimer) });
  }
}

module.exports = { activate };
