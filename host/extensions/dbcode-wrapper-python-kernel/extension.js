'use strict';

const vscode = require('vscode');

const COMMAND = 'dbcodeWrapper.startPythonKernel';
const BOOTSTRAP_FILENAME = 'dbcode-wrapper-python-kernel.ipynb';
const KERNEL_START_TIMEOUT_MS = 45_000;

const bootstrapNotebook = {
  cells: [
    {
      cell_type: 'code',
      execution_count: null,
      metadata: {},
      outputs: [],
      source: [
        "print('DBCode Wrapper Python kernel is ready')"
      ]
    }
  ],
  metadata: {
    language_info: {
      name: 'python'
    }
  },
  nbformat: 4,
  nbformat_minor: 5
};

function delay(milliseconds) {
  return new Promise(resolve => setTimeout(resolve, milliseconds));
}

async function ensureBootstrapNotebook(context) {
  await vscode.workspace.fs.createDirectory(context.globalStorageUri);
  const bootstrapUri = vscode.Uri.joinPath(context.globalStorageUri, BOOTSTRAP_FILENAME);
  try {
    await vscode.workspace.fs.stat(bootstrapUri);
  } catch {
    const contents = Buffer.from(`${JSON.stringify(bootstrapNotebook, null, 2)}\n`, 'utf8');
    await vscode.workspace.fs.writeFile(bootstrapUri, contents);
  }
  return bootstrapUri;
}

async function waitForActiveKernel(jupyter, notebookUri) {
  const deadline = Date.now() + KERNEL_START_TIMEOUT_MS;
  while (Date.now() < deadline) {
    const kernel = await jupyter.exports.kernels.getKernel(notebookUri);
    if (kernel) {
      return kernel;
    }
    await delay(250);
  }
  return undefined;
}

async function returnToDbcode(previousNotebookEditor, previousTextEditor) {
  if (previousNotebookEditor) {
    await vscode.window.showNotebookDocument(previousNotebookEditor.notebook, {
      viewColumn: previousNotebookEditor.viewColumn,
      preserveFocus: false
    });
    return;
  }
  if (previousTextEditor) {
    await vscode.window.showTextDocument(previousTextEditor.document, {
      viewColumn: previousTextEditor.viewColumn,
      preserveFocus: false
    });
    return;
  }
  await vscode.commands.executeCommand('workbench.action.previousEditor');
}

async function startPythonKernel(context) {
  const jupyter = vscode.extensions.getExtension('ms-toolsai.jupyter');
  if (!jupyter) {
    await vscode.window.showErrorMessage('The required Jupyter runtime is missing. Reinstall this approved DBCode Wrapper release.');
    return;
  }

  const previousNotebookEditor = vscode.window.activeNotebookEditor;
  const previousTextEditor = vscode.window.activeTextEditor;
  try {
    await jupyter.activate();
    const bootstrapUri = await ensureBootstrapNotebook(context);
    const document = await vscode.workspace.openNotebookDocument(bootstrapUri);
    const notebookEditor = await vscode.window.showNotebookDocument(document, {
      preview: true,
      preserveFocus: false
    });

    await vscode.commands.executeCommand('notebook.selectKernel', {
      notebookEditor,
      skipIfAlreadySelected: true
    });
    await vscode.commands.executeCommand('notebook.execute', document.uri);

    const kernel = await waitForActiveKernel(jupyter, document.uri);
    if (!kernel) {
      await vscode.window.showErrorMessage('The selected Python kernel did not start. Choose Start Python Kernel and try another environment.');
      return;
    }
    if (kernel.language.toLowerCase() !== 'python') {
      await vscode.window.showErrorMessage(`The selected kernel uses ${kernel.language}, not Python. Choose Start Python Kernel and select a Python environment.`);
      return;
    }

    await returnToDbcode(previousNotebookEditor, previousTextEditor);
    await vscode.window.showInformationMessage('Python kernel ready. Run the Python cell in your DBCode notebook.');
  } catch (error) {
    await returnToDbcode(previousNotebookEditor, previousTextEditor);
    const message = error instanceof Error ? error.message : String(error);
    await vscode.window.showErrorMessage(`Could not start a Python kernel for DBCode: ${message}`);
  }
}

function activate(context) {
  context.subscriptions.push(
    vscode.commands.registerCommand(COMMAND, () => startPythonKernel(context))
  );
}

function deactivate() {}

module.exports = {
  activate,
  deactivate
};
