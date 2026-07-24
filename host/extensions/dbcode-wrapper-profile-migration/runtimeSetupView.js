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

function body(view) {
  if (view.kind === 'progress') {
    return `
      <section class="hero">
        <div class="mark">DB</div>
        <div class="eyebrow">Verified first-run setup</div>
        <h1>Setting up DBCode Wrapper</h1>
        <p>${escapeHtml(view.message)}</p>
      </section>
      <section class="progress-card">
        <strong>${escapeHtml(view.completed)} of ${escapeHtml(view.total)}</strong>
        <span>pinned packages prepared</span>
      </section>
      <section class="notice">Keep this window open. Every package is checked against its approved Open VSX record, size, SHA-256, public key, signature, and extension manifest before installation.</section>`;
  }
  if (view.kind === 'failure') {
    return `
      <section class="hero">
        <div class="mark failure">!</div>
        <div class="eyebrow">Setup stopped safely</div>
        <h1>DBCode Wrapper setup is incomplete</h1>
        <p>${escapeHtml(view.message)}</p>
      </section>
      <section class="notice">Any package installed by this setup came from the same verified set. No different package will be substituted. Check the network connection or remove an unsupported external extension, then retry the same approved package set.</section>
      <div class="actions"><button class="primary" data-action="install-runtime">Retry setup</button></div>`;
  }
  if (view.kind === 'complete') {
    return `
      <section class="hero">
        <div class="mark complete">✓</div>
        <div class="eyebrow">Verified first-run setup</div>
        <h1>DBCode Wrapper is ready</h1>
        <p>The exact DBCode and Python/Jupyter packages are installed outside the application in this Mac's private profile.</p>
      </section>
      <section class="notice">Reload once to activate DBCode. Licence activation and database credentials stay on this Mac and are entered only through DBCode.</section>
      <div class="actions"><button class="primary" data-action="reload">Reload DBCode Wrapper</button></div>`;
  }
  return `
    <section class="hero">
      <div class="mark">DB</div>
      <div class="eyebrow">First launch</div>
      <h1>Set up DBCode Wrapper</h1>
      <p>This fresh Mac needs ${escapeHtml(view.packageCount)} pinned packages, including DBCode ${escapeHtml(view.dbcodeVersion)} and the required Python/Jupyter support.</p>
    </section>
    <section class="notice"><strong>What this action does</strong><p>It downloads only the approved package versions from Open VSX, verifies each package before installation, and stores them outside the signed application in this Mac's private profile.</p></section>
    <section class="notice"><strong>What stays separate</strong><p>Your DBCode licence, account, database credentials, connections, and local data are not downloaded or copied.</p></section>
    <div class="actions"><button class="primary" data-action="install-runtime">Download, verify, and install</button></div>`;
}

function renderRuntimeSetupHtml(view) {
  const nonce = crypto.randomBytes(18).toString('base64');
  return `<!doctype html>
<html lang="en"><head><meta charset="UTF-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-${nonce}';"><meta name="viewport" content="width=device-width,initial-scale=1"><title>DBCode Wrapper Setup</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin: 0; padding: 54px; color: var(--vscode-foreground); background: var(--vscode-editor-background); font: 13px/1.55 var(--vscode-font-family); }
  main { width: min(760px, 100%); margin: 0 auto; }
  h1 { margin: 6px 0 12px; font-size: 30px; line-height: 1.16; letter-spacing: -.02em; }
  p { margin: 0; color: var(--vscode-descriptionForeground); }
  .hero { max-width: 680px; padding: 42px 0 22px; }
  .eyebrow { color: var(--vscode-textLink-foreground); font-size: 11px; font-weight: 700; letter-spacing: .12em; text-transform: uppercase; }
  .mark { display: grid; width: 48px; height: 48px; margin-bottom: 24px; place-items: center; border-radius: 13px; color: white; background: #7057f5; font-weight: 800; }
  .mark.complete { background: #23855b; font-size: 22px; }
  .mark.failure { background: #a33b3b; font-size: 22px; }
  .notice, .progress-card { margin: 14px 0; padding: 17px 19px; border: 1px solid var(--vscode-widget-border); border-radius: 7px; background: var(--vscode-sideBar-background); }
  .notice strong, .notice p, .progress-card strong, .progress-card span { display: block; }
  .notice p { margin-top: 4px; }
  .progress-card strong { font-size: 22px; }
  .progress-card span { color: var(--vscode-descriptionForeground); }
  .actions { display: flex; gap: 9px; margin-top: 24px; }
  button { border: 1px solid var(--vscode-button-border, transparent); border-radius: 6px; padding: 9px 14px; font: inherit; cursor: pointer; }
  button.primary { color: var(--vscode-button-foreground); background: var(--vscode-button-background); }
  button.primary:hover { background: var(--vscode-button-hoverBackground); }
  @media (max-width: 680px) { body { padding: 28px 22px 44px; } }
</style></head><body><main>${body(view)}</main>
<script nonce="${nonce}">const vscode=acquireVsCodeApi();document.addEventListener('click',event=>{const button=event.target.closest('[data-action]');if(button){button.disabled=true;vscode.postMessage({action:button.dataset.action});}});</script>
</body></html>`;
}

module.exports = { renderRuntimeSetupHtml };
