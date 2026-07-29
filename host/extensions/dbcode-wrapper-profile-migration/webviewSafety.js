'use strict';

const crypto = require('node:crypto');

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function renderWebviewDocument({ title, trustedStylesCss, trustedBodyHtml }) {
  const nonce = crypto.randomBytes(18).toString('base64');
  return `<!doctype html>
<html lang="en"><head><meta charset="UTF-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-${nonce}';"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escapeHtml(title)}</title>
<style>${trustedStylesCss}</style></head><body>${trustedBodyHtml}
<script nonce="${nonce}">const vscode=acquireVsCodeApi();document.addEventListener('click',event=>{const button=event.target.closest('[data-action]');if(button){button.disabled=true;vscode.postMessage({action:button.dataset.action});}});</script>
</body></html>`;
}

module.exports = { escapeHtml, renderWebviewDocument };
