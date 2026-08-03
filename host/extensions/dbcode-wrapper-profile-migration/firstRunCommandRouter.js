'use strict';

const START_MIGRATION_COMMAND = 'dbcodeWrapper.startProfileMigration';
const START_RUNTIME_SETUP_COMMAND = 'dbcodeWrapper.startRuntimeSetup';
const STARTING_MESSAGE = 'DBCode Wrapper first-run setup is still starting.';

class FirstRunCommandRouter {
  constructor({ registerCommand, subscriptions, showError }) {
    this.registerCommand = registerCommand;
    this.subscriptions = subscriptions;
    this.showError = showError;
    this.runtimeSetup = undefined;
    this.profileSetup = undefined;
    this.unavailableMessage = undefined;

    this.subscriptions.push(
      this.registerCommand(START_RUNTIME_SETUP_COMMAND, () => this.openRuntimeSetup()),
      this.registerCommand(START_MIGRATION_COMMAND, () => this.openProfileSetup())
    );
  }

  setRuntimeSetup(runtimeSetup) {
    this.runtimeSetup = runtimeSetup;
    this.unavailableMessage = undefined;
  }

  setProfileSetup(profileSetup) {
    this.profileSetup = profileSetup;
  }

  setUnavailable(message) {
    this.unavailableMessage = message;
    this.runtimeSetup = undefined;
    this.profileSetup = undefined;
  }

  unavailable() {
    return this.showError(this.unavailableMessage ?? STARTING_MESSAGE);
  }

  openRuntimeSetup() {
    if (!this.runtimeSetup) {
      return this.unavailable();
    }
    return this.runtimeSetup.open();
  }

  openProfileSetup() {
    if (!this.runtimeSetup) {
      return this.unavailable();
    }
    if (this.runtimeSetup.requiresSetup()) {
      return this.runtimeSetup.open();
    }
    if (!this.profileSetup) {
      return this.unavailable();
    }
    return this.profileSetup.open();
  }
}

function createFirstRunCommandRouter(options) {
  return new FirstRunCommandRouter(options);
}

module.exports = {
  createFirstRunCommandRouter
};
