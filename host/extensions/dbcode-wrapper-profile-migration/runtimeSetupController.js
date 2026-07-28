'use strict';

const fs = require('node:fs/promises');
const { constants: fsConstants } = require('node:fs');
const path = require('node:path');
const { execFile } = require('node:child_process');
const {
  acquireAndVerifyPackage,
  assertManagedRuntimeInstalled,
  missingRuntimePackages,
  validateRuntimeConfiguration
} = require('./runtimeSetup');
const { renderRuntimeSetupHtml } = require('./runtimeSetupView');

const MAX_CONFIGURATION_BYTES = 512 * 1024;
const MAX_CLI_OUTPUT_BYTES = 256 * 1024;

async function loadRuntimeConfiguration(extensionPath) {
  const configurationPath = path.join(extensionPath, 'runtime-extension-set.json');
  const metadata = await fs.lstat(configurationPath);
  if (metadata.isSymbolicLink() || !metadata.isFile() || metadata.size > MAX_CONFIGURATION_BYTES) {
    throw new Error('The focused runtime setup configuration is missing or unsafe.');
  }
  let configuration;
  try {
    configuration = JSON.parse(await fs.readFile(configurationPath, 'utf8'));
  } catch {
    throw new Error('The focused runtime setup configuration is not valid JSON.');
  }
  return validateRuntimeConfiguration(configuration);
}

function pathIsWithin(root, candidate) {
  if (typeof root !== 'string' || typeof candidate !== 'string') {
    return false;
  }
  const relative = path.relative(path.resolve(root), path.resolve(candidate));
  return relative !== '' &&
    relative !== '..' &&
    !relative.startsWith(`..${path.sep}`) &&
    !path.isAbsolute(relative);
}

function extensionInventory(extensions, extensionsRoot) {
  return extensions
    .filter(extension => pathIsWithin(extensionsRoot, extension.extensionPath))
    .map(extension => ({
      id: extension.id.toLowerCase(),
      version: extension.packageJSON?.version
    }));
}

function parseCliInventory(output) {
  const inventory = [];
  for (const line of output.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (trimmed === '') {
      continue;
    }
    const separator = trimmed.lastIndexOf('@');
    if (separator <= 0 || separator === trimmed.length - 1) {
      throw new Error('The host returned an invalid installed-extension inventory.');
    }
    inventory.push({
      id: trimmed.slice(0, separator).toLowerCase(),
      version: trimmed.slice(separator + 1)
    });
  }
  return inventory;
}

function runCli(executable, args) {
  const environment = { ...process.env };
  delete environment.ELECTRON_RUN_AS_NODE;
  return new Promise((resolve, reject) => {
    execFile(executable, args, {
      env: environment,
      maxBuffer: MAX_CLI_OUTPUT_BYTES,
      timeout: 5 * 60 * 1000
    }, (error, stdout) => {
      if (error) {
        reject(new Error('The host could not install the pinned runtime package.'));
        return;
      }
      resolve(stdout);
    });
  });
}

async function rejectUnsafeDirectory(target, label) {
  try {
    const metadata = await fs.lstat(target);
    if (metadata.isSymbolicLink() || !metadata.isDirectory()) {
      throw new Error(`${label} is unsafe.`);
    }
  } catch (error) {
    if (error?.code !== 'ENOENT') {
      throw error;
    }
    await fs.mkdir(target, { mode: 0o700 });
  }
  await fs.chmod(target, 0o700);
}

async function writeVerifiedPackage(cacheRoot, packageRecord, vsix) {
  await rejectUnsafeDirectory(cacheRoot, 'The runtime setup cache');
  const idRoot = path.join(cacheRoot, packageRecord.id);
  await rejectUnsafeDirectory(idRoot, 'A runtime setup package directory');
  const packageRoot = path.join(idRoot, packageRecord.version);
  await rejectUnsafeDirectory(packageRoot, 'A runtime setup version directory');
  const destination = path.join(packageRoot, 'package.vsix');
  const temporary = path.join(packageRoot, `.package.${process.pid}.${Date.now()}.tmp`);
  await fs.writeFile(temporary, vsix, { mode: 0o600, flag: 'wx' });
  await fs.chmod(temporary, 0o600);
  await fs.rename(temporary, destination);
  return destination;
}

class RuntimeSetupController {
  constructor({
    context,
    vscode,
    layout,
    configuration,
    acquirePackage = acquireAndVerifyPackage,
    executeCli = runCli
  }) {
    this.context = context;
    this.vscode = vscode;
    this.layout = layout;
    this.configuration = configuration;
    this.acquirePackage = acquirePackage;
    this.executeCli = executeCli;
    this.panel = undefined;
    this.installing = false;
    this.cacheRoot = path.join(context.globalStorageUri.fsPath, 'runtime-setup-cache');
    this.cli = path.join(vscode.env.appRoot, 'bin', configuration.application_name);
  }

  missingPackages() {
    return missingRuntimePackages(
      this.configuration,
      extensionInventory(this.vscode.extensions.all, this.layout.extensionsRoot)
    );
  }

  requiresSetup() {
    try {
      assertManagedRuntimeInstalled(
        this.configuration,
        extensionInventory(this.vscode.extensions.all, this.layout.extensionsRoot)
      );
      return false;
    } catch {
      return true;
    }
  }

  open() {
    if (this.panel) {
      this.panel.reveal(this.vscode.ViewColumn.Active);
      return;
    }
    this.panel = this.vscode.window.createWebviewPanel(
      'dbcodeWrapper.runtimeSetup',
      'DBCode Wrapper Setup',
      this.vscode.ViewColumn.Active,
      { enableScripts: true, retainContextWhenHidden: false }
    );
    const dbcodeVersion = this.configuration.packages.find(item => item.id === 'dbcode.dbcode').version;
    this.panel.webview.html = renderRuntimeSetupHtml({
      kind: 'welcome',
      packageCount: this.configuration.packages.length,
      dbcodeVersion
    });
    this.panel.webview.onDidReceiveMessage(
      message => this.handleMessage(message),
      undefined,
      this.context.subscriptions
    );
    this.panel.onDidDispose(() => {
      this.panel = undefined;
    }, undefined, this.context.subscriptions);
  }

  render(view) {
    if (this.panel) {
      this.panel.webview.html = renderRuntimeSetupHtml(view);
    }
  }

  profileArguments() {
    return [
      '--user-data-dir', this.layout.userDataRoot,
      '--extensions-dir', this.layout.extensionsRoot,
      '--shared-data-dir', this.layout.sharedDataRoot,
      '--disable-updates'
    ];
  }

  async install() {
    if (this.installing) {
      return;
    }
    this.installing = true;
    const missing = this.missingPackages();
    try {
      await fs.access(this.cli, fsConstants.X_OK);
    } catch {
      this.installing = false;
      this.render({ kind: 'failure', message: 'The focused host installer is unavailable in this application.' });
      return;
    }

    try {
      let completed = 0;
      for (const packageRecord of missing) {
        this.render({
          kind: 'progress',
          completed,
          total: missing.length,
          message: `Verifying ${packageRecord.id}@${packageRecord.version} from Open VSX…`
        });
        const vsix = await this.acquirePackage(
          packageRecord,
          this.configuration.public_keys,
          this.configuration.code_oss_version
        );
        const packagePath = await writeVerifiedPackage(this.cacheRoot, packageRecord, vsix);
        await this.executeCli(this.cli, [
          ...this.profileArguments(),
          '--install-extension', packagePath,
          '--do-not-include-pack-dependencies',
          '--force'
        ]);
        completed += 1;
      }
      const output = await this.executeCli(this.cli, [
        ...this.profileArguments(),
        '--list-extensions',
        '--show-versions'
      ]);
      assertManagedRuntimeInstalled(this.configuration, parseCliInventory(output));
      this.render({ kind: 'complete' });
    } catch (error) {
      const message = error instanceof Error
        ? error.message
        : 'The pinned runtime setup could not be completed.';
      this.render({ kind: 'failure', message });
    } finally {
      this.installing = false;
    }
  }

  async handleMessage(message) {
    if (message?.action === 'install-runtime') {
      await this.install();
    } else if (message?.action === 'reload') {
      await this.vscode.commands.executeCommand('workbench.action.reloadWindow');
    }
  }
}

module.exports = {
  RuntimeSetupController,
  extensionInventory,
  loadRuntimeConfiguration,
  pathIsWithin,
  parseCliInventory,
  runCli,
  writeVerifiedPackage
};
