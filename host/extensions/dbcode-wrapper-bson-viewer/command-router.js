'use strict';

const OPEN_CLIPBOARD_COMMAND = 'dbcodeWrapper.openBsonResultFromClipboard';
const OPEN_FILE_COMMAND = 'dbcodeWrapper.openBsonResultFromFile';

function registerBsonViewerCommands({ registerCommand, subscriptions, viewer }) {
  if (typeof registerCommand !== 'function' || !Array.isArray(subscriptions) ||
      !viewer || typeof viewer.openClipboard !== 'function' || typeof viewer.openFile !== 'function') {
    throw new TypeError('BSON Result Viewer command dependencies are incomplete.');
  }
  subscriptions.push(
    registerCommand(OPEN_CLIPBOARD_COMMAND, () => viewer.openClipboard()),
    registerCommand(OPEN_FILE_COMMAND, () => viewer.openFile())
  );
}

module.exports = { registerBsonViewerCommands };
