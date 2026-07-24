'use strict';

const crypto = require('node:crypto');
const path = require('node:path');
const { REVIEWED_FIELDS } = require('./migration');

const DETAIL_FIELDS = REVIEWED_FIELDS.filter(field => field !== 'name');

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function connectionLabel(connection, index) {
  return connection.name || connection.database || (connection.path ? path.basename(connection.path) : `Connection ${index + 1}`);
}

function detailRows(connection) {
  return DETAIL_FIELDS
    .filter(field => connection[field] !== undefined)
    .map(field => `<div class="detail"><span>${escapeHtml(field === 'type' ? 'Database type' : field)}</span><strong>${escapeHtml(connection[field])}</strong></div>`)
    .join('');
}

function connectionCards(connections) {
  return connections.map((connection, index) => `
    <article class="connection-card">
      <div class="connection-title"><span class="database-icon">▤</span>${escapeHtml(connectionLabel(connection, index))}</div>
      ${detailRows(connection)}
    </article>`).join('');
}

function pageBody(view) {
  if (view.kind === 'preview') {
    return `
      <section class="hero compact">
        <div class="eyebrow">Standalone DBCode Profile setup</div>
        <h1>Review connection details</h1>
        <p>Only the fields shown below can enter DBCode Wrapper. Passwords, tokens, private keys, licence data, and old connection identifiers are never migrated.</p>
      </section>
      <section class="summary-grid">
        <div><strong>${view.plan.ready.length}</strong><span>Ready for DBCode</span></div>
        <div class="${view.plan.preflight.length ? 'attention' : ''}"><strong>${view.plan.preflight.length}</strong><span>Need DuckDB preflight</span></div>
      </section>
      <section>
        <h2>Reviewed connections</h2>
        <div class="cards">${connectionCards(view.plan.ready)}</div>
      </section>
      ${view.plan.preflight.length ? `
        <section class="notice warning">
          <h2>Deferred from the batch import</h2>
          <p>A DuckDB filename stem contains a hyphen. It will not be included in the reviewed import file. Test it separately with this exact DBCode version using a read-only query; the wrapper never renames, moves, or rewrites the database.</p>
          <div class="cards">${connectionCards(view.plan.preflight.map(item => item.connection))}</div>
        </section>` : ''}
      <div class="actions">
        <button class="primary" data-action="confirm-review">Continue</button>
        <button data-action="choose-file">Choose another file</button>
        <button class="quiet" data-action="cancel">Cancel</button>
      </div>`;
  }
  if (view.kind === 'import') {
    return `
      <section class="hero compact">
        <div class="eyebrow">Reviewed file ready</div>
        <h1>Continue in DBCode Import</h1>
        <p>DBCode will ask you to map and preview these reviewed fields again before importing. Choose CSV, then select the owner-only file below.</p>
      </section>
      <section class="file-card">
        <span>Reviewed temporary file</span>
        <code>${escapeHtml(view.inventoryPath)}</code>
      </section>
      <section class="notice">
        <strong>Protected information stays separate.</strong>
        <p>The staged CSV derives DBCode's connection type as host or socket from the reviewed host or local path. Re-enter database passwords only when DBCode asks. Activate your lifetime Pro licence normally in DBCode Account. If DBCode does not offer a valid mapping for a connection, leave that connection out and add it manually.</p>
      </section>
      <div class="actions">
        <button class="primary" data-action="open-import">Open DBCode Import</button>
        <button data-action="copy-path">Copy reviewed file path</button>
        <button class="quiet" data-action="cancel">Cancel and delete file</button>
      </div>`;
  }
  if (view.kind === 'confirm-import') {
    return `
      <section class="hero compact">
        <div class="eyebrow">DBCode import</div>
        <h1>Did the reviewed import finish?</h1>
        <p>Confirm only after checking DBCode's own field mapping and preview. The temporary reviewed file is deleted when you finish or cancel.</p>
      </section>
      <div class="actions">
        <button class="primary" data-action="finish-import">Import finished</button>
        <button data-action="open-import">Open DBCode Import again</button>
        <button data-action="recreate-profile">Back up and recreate profile…</button>
        <button class="quiet" data-action="cancel">Cancel and delete file</button>
      </div>`;
  }
  if (view.kind === 'preflight') {
    return `
      <section class="hero compact">
        <div class="eyebrow">Conditional compatibility check</div>
        <h1>Test the deferred DuckDB connection</h1>
        <p>Connection ${view.position} of ${view.total} was left out of the batch import. Add it manually in DBCode ${escapeHtml(view.dbcodeVersion)}, select it in a new query, and run the read-only statement below.</p>
      </section>
      <section class="file-card"><span>Read-only statement</span><code>SELECT 1 AS dbcode_wrapper_read_only_preflight;</code></section>
      <div class="cards">${connectionCards([view.connection])}</div>
      <section class="notice warning"><strong>Do not rename the database to make the test pass.</strong><p>If DBCode reports a syntax or connection error, leave only that connection deferred. The rest of the migration remains accepted.</p></section>
      <div class="actions">
        <button class="primary" data-action="preflight-passed">The read-only preflight returned 1</button>
        <button data-action="keep-deferred">Keep this connection deferred</button>
      </div>`;
  }
  if (view.kind === 'complete') {
    return `
      <section class="hero">
        <div class="success-mark">✓</div>
        <div class="eyebrow">Standalone DBCode Profile</div>
        <h1>Profile setup is complete</h1>
        <p>${escapeHtml(view.message)}</p>
      </section>
      <section class="notice"><strong>Your other editor profiles were not used.</strong><p>DBCode Wrapper did not copy normal VS Code settings, extension state, account data, machine identity, licence state, or Keychain records.</p></section>
      <div class="actions"><button class="primary" data-action="open-connections">Open connections</button><button data-action="recreate-profile">Back up and recreate profile…</button><button data-action="close">Close</button></div>`;
  }
  return `
    <section class="hero">
      <div class="profile-mark">DB</div>
      <div class="eyebrow">First launch</div>
      <h1>Set up your Standalone DBCode Profile</h1>
      <p>Start clean, or review a JSON or CSV connection inventory before handing it to DBCode's supported importer.</p>
    </section>
    <section class="choice-grid">
      <button class="choice primary-choice" data-action="choose-file"><strong>Review an import file</strong><span>Allow only connection names, types, hosts, ports, databases, usernames, SSL choices, and reviewed local paths.</span></button>
      <button class="choice" data-action="start-fresh"><strong>Start fresh</strong><span>Add connections manually, re-enter protected credentials, and activate your lifetime Pro licence normally.</span></button>
    </section>
    <section class="notice"><strong>Nothing is copied automatically.</strong><p>Normal VS Code, VSCodium, Keychain, Settings Sync, extension state, and licence storage are never used as migration sources.</p></section>
    <div class="actions"><button class="quiet" data-action="later">Not now</button><button class="quiet" data-action="recreate-profile">Back up and recreate profile…</button></div>`;
}

function renderProfileSetupHtml(view) {
  const nonce = crypto.randomBytes(18).toString('base64');
  return `<!doctype html>
<html lang="en"><head><meta charset="UTF-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-${nonce}';"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Profile Setup</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin: 0; padding: 48px 54px 60px; color: var(--vscode-foreground); background: var(--vscode-editor-background); font: 13px/1.55 var(--vscode-font-family); }
  main { width: min(920px, 100%); margin: 0 auto; }
  h1 { margin: 6px 0 12px; font-size: 30px; line-height: 1.16; letter-spacing: -0.02em; }
  h2 { margin: 30px 0 12px; font-size: 15px; }
  p { margin: 0; color: var(--vscode-descriptionForeground); }
  .hero { max-width: 700px; padding: 42px 0 26px; }
  .hero.compact { padding-top: 14px; }
  .eyebrow { color: var(--vscode-textLink-foreground); font-size: 11px; font-weight: 700; letter-spacing: .12em; text-transform: uppercase; }
  .profile-mark, .success-mark { display: grid; width: 48px; height: 48px; margin-bottom: 24px; place-items: center; border-radius: 13px; color: white; background: #7057f5; font-weight: 800; }
  .success-mark { background: #23855b; font-size: 24px; }
  button { border: 1px solid var(--vscode-button-border, transparent); border-radius: 6px; padding: 9px 14px; color: var(--vscode-button-secondaryForeground); background: var(--vscode-button-secondaryBackground); font: inherit; cursor: pointer; text-align: left; }
  button:hover { background: var(--vscode-button-secondaryHoverBackground); }
  button.primary { color: var(--vscode-button-foreground); background: var(--vscode-button-background); }
  button.primary:hover { background: var(--vscode-button-hoverBackground); }
  button.quiet { border-color: transparent; background: transparent; }
  .choice-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; margin: 18px 0 22px; }
  .choice { min-height: 130px; padding: 22px; border-color: var(--vscode-widget-border); background: var(--vscode-sideBar-background); }
  .choice.primary-choice { border-color: var(--vscode-focusBorder); }
  .choice strong, .choice span { display: block; }
  .choice strong { margin-bottom: 8px; color: var(--vscode-foreground); font-size: 14px; }
  .choice span { color: var(--vscode-descriptionForeground); }
  .notice, .file-card { margin: 18px 0; padding: 16px 18px; border: 1px solid var(--vscode-widget-border); border-radius: 7px; background: var(--vscode-sideBar-background); }
  .notice.warning { border-color: var(--vscode-editorWarning-foreground); }
  .notice strong, .file-card span, .file-card code { display: block; }
  .notice p { margin-top: 4px; }
  .file-card code { margin-top: 8px; overflow-wrap: anywhere; color: var(--vscode-textPreformat-foreground); }
  .summary-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px; margin: 20px 0; }
  .summary-grid > div { padding: 18px; border: 1px solid var(--vscode-widget-border); border-radius: 7px; background: var(--vscode-sideBar-background); }
  .summary-grid strong, .summary-grid span { display: block; }
  .summary-grid strong { font-size: 22px; }
  .summary-grid span { color: var(--vscode-descriptionForeground); }
  .summary-grid .attention { border-color: var(--vscode-editorWarning-foreground); }
  .cards { display: grid; gap: 10px; }
  .connection-card { padding: 16px 18px; border: 1px solid var(--vscode-widget-border); border-radius: 7px; background: var(--vscode-sideBar-background); }
  .connection-title { margin-bottom: 10px; font-weight: 700; }
  .database-icon { margin-right: 8px; color: var(--vscode-textLink-foreground); }
  .detail { display: grid; grid-template-columns: 130px 1fr; gap: 12px; padding: 3px 0; }
  .detail span { color: var(--vscode-descriptionForeground); text-transform: capitalize; }
  .detail strong { min-width: 0; overflow-wrap: anywhere; font-weight: 500; }
  .actions { display: flex; flex-wrap: wrap; gap: 9px; margin-top: 24px; }
  @media (max-width: 680px) { body { padding: 28px 22px 44px; } .choice-grid, .summary-grid { grid-template-columns: 1fr; } .detail { grid-template-columns: 100px 1fr; } }
</style></head><body><main>${pageBody(view)}</main>
<script nonce="${nonce}">const vscode=acquireVsCodeApi();document.addEventListener('click',event=>{const button=event.target.closest('[data-action]');if(button){button.disabled=true;vscode.postMessage({action:button.dataset.action});}});</script>
</body></html>`;
}

module.exports = { renderProfileSetupHtml };
