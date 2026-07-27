'use strict';

const { advancePreflight, createMigrationPlan, parseInventory } = require('./migration');
const { requireMatchingRelaunchPath } = require('./profileRecovery');

const PROFILE_SETUP_STATE_KEY = 'dbcodeWrapper.profileSetup.v1';
const MAX_CONNECTIONS = 500;

class ProfileSetup {
  constructor(adapter) {
    this.adapter = adapter;
    this.plan = undefined;
    this.staged = undefined;
    this.preflightProgress = { completed: 0, deferred: [] };
  }

  async requiresSetup() {
    const state = await this.adapter.loadState();
    return state?.schemaVersion !== 1 || state.status !== 'complete';
  }

  async open() {
    this.adapter.render({ kind: 'welcome' });
  }

  async dispatch(action) {
    try {
      await this.performAction(action);
    } catch (error) {
      await this.showFailure(error);
    }
  }

  async performAction(action) {
    switch (action) {
      case 'choose-file': return this.chooseFile();
      case 'confirm-review': return this.confirmReview();
      case 'open-import': return this.openImport();
      case 'copy-path': return this.copyPath();
      case 'finish-import': return this.finishImport();
      case 'cancel': return this.cancel();
      case 'start-fresh': return this.complete(
        'fresh',
        0,
        'A Standalone DBCode Profile is ready. Add connections and activate DBCode normally.'
      );
      case 'preflight-passed': return this.finishPreflight('passed');
      case 'keep-deferred': return this.finishPreflight('deferred');
      case 'open-connections':
        await this.adapter.focusConnections();
        return this.close();
      case 'later': return this.close();
      case 'close': return this.close();
      case 'recreate-profile': return this.recreateProfile();
    }
  }

  async chooseFile() {
    const selected = await this.adapter.chooseInventory();
    if (!selected) {
      return;
    }
    const connections = parseInventory(selected.contents, selected.format);
    if (connections.length === 0 || connections.length > MAX_CONNECTIONS) {
      throw new Error('The inventory must contain between 1 and 500 connections.');
    }
    await this.cleanupStaged();
    this.plan = createMigrationPlan(connections);
    this.preflightProgress = { completed: 0, deferred: [] };
    this.adapter.render({ kind: 'preview', plan: this.plan });
  }

  async confirmReview() {
    if (!this.plan) {
      return;
    }
    await this.cleanupStaged();
    if (this.plan.ready.length > 0) {
      this.staged = await this.adapter.stageInventory(this.plan.ready);
      this.adapter.render({ kind: 'import', inventoryPath: this.staged.inventoryPath });
    } else {
      await this.showPreflight();
    }
  }

  async openImport() {
    if (!this.staged) {
      return;
    }
    await this.adapter.openDbcodeImport();
    this.adapter.revealPanel();
    this.adapter.render({ kind: 'confirm-import' });
  }

  async copyPath() {
    if (!this.staged) {
      return;
    }
    await this.adapter.copyText(this.staged.inventoryPath);
    await this.adapter.showInfo('The reviewed temporary file path was copied.');
    this.adapter.render({ kind: 'import', inventoryPath: this.staged.inventoryPath });
  }

  async cleanupStaged() {
    if (!this.staged) {
      return;
    }
    const staged = this.staged;
    await this.adapter.cleanupInventory(staged);
    if (this.staged === staged) {
      this.staged = undefined;
    }
  }

  async finishImport() {
    await this.cleanupStaged();
    if (this.plan?.preflight.length) {
      await this.showPreflight();
    } else {
      await this.complete(
        'imported',
        0,
        'Reviewed connection details were handed to DBCode. Re-enter protected credentials when DBCode asks.'
      );
    }
  }

  async showPreflight() {
    const item = this.plan?.preflight[this.preflightProgress.completed];
    if (!item) {
      throw new Error('There is no pending DuckDB preflight connection.');
    }
    this.adapter.render({
      kind: 'preflight',
      dbcodeVersion: this.adapter.dbcodeVersion(),
      connection: item.connection,
      position: this.preflightProgress.completed + 1,
      total: this.plan.preflight.length
    });
  }

  async finishPreflight(outcome) {
    this.preflightProgress = advancePreflight(
      this.plan?.preflight ?? [],
      this.preflightProgress,
      outcome
    );
    if (this.preflightProgress.completed < (this.plan?.preflight.length ?? 0)) {
      await this.showPreflight();
      return;
    }
    const deferredConnectionCount = this.preflightProgress.deferred.length;
    if (deferredConnectionCount > 0) {
      const deferredSummary = deferredConnectionCount === 1
        ? '1 DuckDB connection remains deferred without changing its file.'
        : `${deferredConnectionCount} DuckDB connections remain deferred without changing their files.`;
      await this.complete(
        'imported-with-deferred',
        deferredConnectionCount,
        `Profile setup is complete. ${deferredSummary}`
      );
      return;
    }
    await this.complete(
      'imported-with-preflight',
      0,
      'Profile setup is complete and every conditional DuckDB preflight passed.'
    );
  }

  reset() {
    this.plan = undefined;
    this.preflightProgress = { completed: 0, deferred: [] };
  }

  async cancel() {
    await this.cleanupStaged();
    this.reset();
    this.adapter.render({ kind: 'welcome' });
  }

  async close() {
    await this.cleanupStaged();
    this.reset();
    this.adapter.closePanel();
  }

  async panelClosed() {
    try {
      await this.cleanupStaged();
    } finally {
      this.reset();
    }
  }

  recoveryRequest() {
    const {
      layout,
      processPids,
      relaunchArguments,
      settingsSource
    } = this.adapter.recoveryContext();
    let relaunchArgs = [];
    if (relaunchArguments) {
      try {
        relaunchArgs = JSON.parse(relaunchArguments);
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
    const timestamp = this.adapter.now().toISOString().replaceAll(/[-:.]/g, '');
    return {
      processPids: [...new Set(processPids)],
      recoveryId: `${timestamp}-${this.adapter.randomUUID()}`,
      profileLayout: layout.profileLayout,
      userDataRoot: layout.userDataRoot,
      sharedDataRoot: layout.sharedDataRoot,
      backupRoot: layout.backupRoot,
      settingsSource,
      appBundle: layout.appBundle,
      relaunchArgs,
      relaunchApplication: true
    };
  }

  async recreateProfile() {
    if (!await this.adapter.confirmRecovery()) {
      return;
    }
    await this.cleanupStaged();
    await this.adapter.startRecovery(this.recoveryRequest());
    await this.adapter.quit();
  }

  async showFailure(error) {
    const message = error instanceof Error
      ? error.message
      : 'Profile setup could not continue.';
    let cleanupFailed = false;
    try {
      await this.cleanupStaged();
    } catch {
      cleanupFailed = true;
    }
    const cleanupMessage = cleanupFailed
      ? ' The temporary reviewed file could not be removed automatically.'
      : '';
    await this.adapter.showError(`This connection inventory was not accepted. ${message}${cleanupMessage}`);
    if (this.staged) {
      this.adapter.render({ kind: 'import', inventoryPath: this.staged.inventoryPath });
    } else if (this.plan) {
      this.adapter.render({ kind: 'preview', plan: this.plan });
    } else {
      this.adapter.render({ kind: 'welcome' });
    }
  }

  async complete(mode, deferredConnectionCount, message) {
    await this.cleanupStaged();
    const state = {
      schemaVersion: 1,
      status: 'complete',
      mode,
      deferredConnectionCount,
      completedAt: this.adapter.now().toISOString()
    };
    await this.adapter.saveState(state);
    this.adapter.render({ kind: 'complete', message });
  }
}

module.exports = {
  PROFILE_SETUP_STATE_KEY,
  ProfileSetup
};
