'use strict';

const vscode = require('vscode');
const { createBsonResultViewer } = require('./bson-result-viewer');
const { registerBsonViewerCommands } = require('./command-router');
const { createDisplayDocument } = require('./ejson-display');
const { renderViewerDocument } = require('./viewer-webview');

const VIEW_TYPE = 'dbcodeWrapper.bsonResultViewer';

function createDocumentPresenter(context) {
  let panel;
  let latestPayload;

  async function publishLatest() {
    if (panel && latestPayload) {
      await panel.webview.postMessage(latestPayload);
    }
  }

  function createPanel() {
    const createdPanel = vscode.window.createWebviewPanel(
      VIEW_TYPE,
      'BSON Result Viewer',
      vscode.ViewColumn.Active,
      {
        enableScripts: true,
        retainContextWhenHidden: false,
        localResourceRoots: []
      }
    );
    panel = createdPanel;
    context.subscriptions.push(
      createdPanel,
      createdPanel.onDidDispose(() => {
        if (panel === createdPanel) {
          panel = undefined;
          latestPayload = undefined;
        }
      }),
      createdPanel.webview.onDidReceiveMessage(async message => {
        if (message?.type === 'ready') {
          await publishLatest();
          return;
        }
        if (message?.type === 'parseEmbedded' && panel === createdPanel && latestPayload &&
            latestPayload.document.embeddedJsonIncluded !== true) {
          try {
            const document = createDisplayDocument(latestPayload.document.rawText, { parseEmbedded: true });
            latestPayload = { ...latestPayload, document };
            await publishLatest();
          } catch (error) {
            await createdPanel.webview.postMessage({ type: 'embeddedParseFailed' });
            const detail = error instanceof Error ? error.message : String(error);
            await vscode.window.showErrorMessage(`Could not parse JSON strings: ${detail}`);
          }
          return;
        }
        if (message?.type === 'copy' && typeof message.value === 'string') {
          try {
            await vscode.env.clipboard.writeText(message.value);
            await createdPanel.webview.postMessage({ type: 'copySucceeded' });
          } catch {
            await createdPanel.webview.postMessage({ type: 'copyFailed' });
            await vscode.window.showErrorMessage('Could not copy the displayed BSON value.');
          }
        }
      })
    );
    createdPanel.webview.html = renderViewerDocument();
    return createdPanel;
  }

  return async (document, origin) => {
    latestPayload = { type: 'document', document, origin };
    if (!panel) {
      createPanel();
    } else {
      panel.reveal(vscode.ViewColumn.Active, false);
    }
    await publishLatest();
  };
}

function activate(context) {
  const viewer = createBsonResultViewer({
    chooseFile: async () => {
      const files = await vscode.window.showOpenDialog({
        title: 'Open BSON or Extended JSON Result',
        openLabel: 'Open Result',
        canSelectFiles: true,
        canSelectFolders: false,
        canSelectMany: false,
        filters: {
          'JSON results': ['json', 'ejson']
        }
      });
      return files?.[0];
    },
    getFileSize: async uri => (await vscode.workspace.fs.stat(uri)).size,
    readClipboard: () => vscode.env.clipboard.readText(),
    readFile: uri => vscode.workspace.fs.readFile(uri),
    showDocument: createDocumentPresenter(context),
    showError: message => vscode.window.showErrorMessage(message)
  });

  registerBsonViewerCommands({
    registerCommand: (command, handler) => vscode.commands.registerCommand(command, handler),
    subscriptions: context.subscriptions,
    viewer
  });
}

function deactivate() {}

module.exports = {
  activate,
  deactivate
};
