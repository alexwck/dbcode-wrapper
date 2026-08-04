'use strict';

const crypto = require('node:crypto');

function renderViewerDocument() {
  const nonce = crypto.randomBytes(18).toString('base64');
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light dark">
  <title>BSON Result Viewer</title>
  <style nonce="${nonce}">
    :root { color-scheme: light dark; }
    * { box-sizing: border-box; }
    body { margin: 0; color: var(--vscode-foreground); background: var(--vscode-editor-background); font: 13px/1.45 var(--vscode-font-family); }
    header { position: sticky; top: 0; z-index: 4; padding: 18px 22px 14px; border-bottom: 1px solid var(--vscode-panel-border); background: var(--vscode-editor-background); }
    .heading { display: flex; align-items: baseline; gap: 10px; min-width: 0; }
    h1 { margin: 0; font-size: 17px; font-weight: 600; }
    #origin { color: var(--vscode-descriptionForeground); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .controls { display: flex; align-items: center; flex-wrap: wrap; gap: 8px; margin-top: 14px; }
    .modes { display: inline-flex; border: 1px solid var(--vscode-button-border, var(--vscode-panel-border)); border-radius: 5px; overflow: hidden; }
    button { color: var(--vscode-button-secondaryForeground); background: var(--vscode-button-secondaryBackground); border: 0; cursor: pointer; font: inherit; }
    button:hover { background: var(--vscode-button-secondaryHoverBackground); }
    .mode { min-width: 68px; padding: 6px 10px; border-right: 1px solid var(--vscode-button-border, var(--vscode-panel-border)); }
    .mode:last-child { border-right: 0; }
    .mode.active { color: var(--vscode-button-foreground); background: var(--vscode-button-background); }
    #search { flex: 1 1 260px; min-width: 180px; height: 30px; padding: 4px 9px; color: var(--vscode-input-foreground); background: var(--vscode-input-background); border: 1px solid var(--vscode-input-border, transparent); outline: none; }
    #search:focus { border-color: var(--vscode-focusBorder); }
    .embedded-toggle { display: inline-flex; align-items: center; gap: 6px; color: var(--vscode-descriptionForeground); white-space: nowrap; }
    .embedded-toggle input { accent-color: var(--vscode-button-background); }
    #summary { margin-left: auto; color: var(--vscode-descriptionForeground); white-space: nowrap; }
    main { padding: 14px 22px 32px; }
    .empty { padding: 30px 4px; color: var(--vscode-descriptionForeground); }
    details { margin-left: 18px; }
    details.root { margin-left: 0; }
    summary { cursor: pointer; }
    summary::marker { color: var(--vscode-descriptionForeground); }
    .node-row { display: grid; grid-template-columns: minmax(120px, .8fr) minmax(180px, 2fr) minmax(90px, auto) 28px; align-items: start; gap: 12px; min-height: 28px; padding: 4px 5px; border-radius: 4px; }
    .node-row:hover { background: var(--vscode-list-hoverBackground); }
    .node-key { color: var(--vscode-symbolIcon-propertyForeground, var(--vscode-foreground)); font-family: var(--vscode-editor-font-family); overflow-wrap: anywhere; }
    .node-value { white-space: pre-wrap; overflow-wrap: anywhere; font-family: var(--vscode-editor-font-family); }
    .node-type { justify-self: start; padding: 1px 6px; border: 1px solid var(--vscode-badge-background); border-radius: 999px; color: var(--vscode-badge-foreground); background: color-mix(in srgb, var(--vscode-badge-background) 45%, transparent); font-size: 11px; white-space: nowrap; }
    .copy { width: 26px; height: 24px; padding: 0; border-radius: 4px; color: var(--vscode-descriptionForeground); background: transparent; }
    .copy:hover { color: var(--vscode-foreground); background: var(--vscode-toolbar-hoverBackground); }
    .embedded { margin: 3px 0 5px 18px; padding-left: 8px; border-left: 2px solid var(--vscode-textLink-foreground); }
    .limit-note { margin: 8px 0 8px 18px; color: var(--vscode-descriptionForeground); }
    table { width: 100%; border-collapse: collapse; table-layout: fixed; }
    th, td { padding: 7px 9px; border-bottom: 1px solid var(--vscode-panel-border); text-align: left; vertical-align: top; }
    th { position: sticky; top: 105px; z-index: 2; color: var(--vscode-descriptionForeground); background: var(--vscode-editor-background); font-weight: 600; }
    th:nth-child(1) { width: 42%; } th:nth-child(2) { width: 38%; } th:nth-child(3) { width: 16%; } th:nth-child(4) { width: 36px; }
    td.path, td.value { white-space: pre-wrap; overflow-wrap: anywhere; font-family: var(--vscode-editor-font-family); }
    pre { margin: 0; padding: 14px; overflow: auto; border: 1px solid var(--vscode-panel-border); border-radius: 5px; background: var(--vscode-textCodeBlock-background); font: 12px/1.5 var(--vscode-editor-font-family); white-space: pre; tab-size: 2; }
    #toast { position: fixed; right: 22px; bottom: 20px; z-index: 6; min-width: 90px; padding: 7px 11px; border-radius: 4px; color: var(--vscode-notifications-foreground); background: var(--vscode-notifications-background); border: 1px solid var(--vscode-notifications-border); opacity: 0; transform: translateY(5px); pointer-events: none; transition: opacity .12s, transform .12s; }
    #toast.visible { opacity: 1; transform: translateY(0); }
    @media (max-width: 720px) { header, main { padding-left: 12px; padding-right: 12px; } .node-row { grid-template-columns: minmax(90px, .8fr) minmax(120px, 1.5fr) auto 28px; gap: 7px; } #summary { display: none; } }
  </style>
</head>
<body>
  <header>
    <div class="heading"><h1>BSON Result Viewer</h1><span id="origin">Waiting for JSON…</span></div>
    <div class="controls">
      <div class="modes" role="tablist" aria-label="Viewer mode">
        <button class="mode active" data-mode="tree" role="tab" aria-selected="true">Tree</button>
        <button class="mode" data-mode="table" role="tab" aria-selected="false">Table</button>
        <button class="mode" data-mode="raw" role="tab" aria-selected="false">JSON</button>
      </div>
      <input id="search" type="search" aria-label="Search result" placeholder="Search path, value, or type">
      <label class="embedded-toggle"><input id="parse-embedded" type="checkbox"> Parse JSON strings</label>
      <span id="summary" aria-live="polite"></span>
    </div>
  </header>
  <main id="content"><div class="empty">Copy a DBCode JSON result, then open this viewer again.</div></main>
  <div id="toast" role="status" aria-live="polite">Copied</div>
  <script nonce="${nonce}">
    const vscode = acquireVsCodeApi();
    const content = document.getElementById('content');
    const origin = document.getElementById('origin');
    const search = document.getElementById('search');
    const parseEmbedded = document.getElementById('parse-embedded');
    const summary = document.getElementById('summary');
    const toast = document.getElementById('toast');
    const copyValues = new WeakMap();
    const TREE_NODE_LIMIT = 5_000;
    const TABLE_ROW_LIMIT = 5_000;
    const saved = vscode.getState() || {};
    let activeMode = ['tree', 'table', 'raw'].includes(saved.mode) ? saved.mode : 'tree';
    let displayDocument;
    let embeddedParsePending = false;
    let toastTimer;

    search.value = '';
    parseEmbedded.checked = saved.parseEmbedded === true;

    function makeElement(tag, className, text) {
      const value = document.createElement(tag);
      if (className) value.className = className;
      if (text !== undefined) value.textContent = text;
      return value;
    }

    function visibleChildren(node) {
      const children = [...node.children];
      if (parseEmbedded.checked && node.embeddedJson) children.push(node.embeddedJson);
      return children;
    }

    function matches(node, query) {
      if (!query) return true;
      const ownText = [node.path, node.key, node.displayValue, node.type].join('\\n').toLocaleLowerCase();
      return ownText.includes(query) || visibleChildren(node).some(child => matches(child, query));
    }

    function copyButton(node) {
      if (typeof node.copyValue !== 'string') {
        return makeElement('span');
      }
      const button = makeElement('button', 'copy', '⧉');
      button.type = 'button';
      button.title = 'Copy displayed value';
      button.setAttribute('aria-label', 'Copy value at ' + node.path);
      copyValues.set(button, node.copyValue);
      return button;
    }

    function appendNodeCells(row, node) {
      row.append(
        makeElement('span', 'node-key', node.key),
        makeElement('span', 'node-value', node.displayValue),
        makeElement('span', 'node-type', node.type),
        copyButton(node)
      );
    }

    function appendTreeLimit(container, treeState) {
      if (treeState.limitNoticeShown) return;
      treeState.limitNoticeShown = true;
      container.append(makeElement('div', 'limit-note', 'Tree display limit reached. Refine the search to inspect other values.'));
    }

    function treeNode(node, query, depth, treeState) {
      treeState.renderedNodes += 1;
      const children = visibleChildren(node).filter(child => matches(child, query));
      if (children.length > 0) {
        const details = makeElement('details', depth === 0 ? 'root' : '');
        details.open = depth < 2 || Boolean(query);
        const heading = makeElement('summary');
        const row = makeElement('span', 'node-row');
        appendNodeCells(row, node);
        heading.append(row);
        const childContainer = makeElement('div');
        const populate = () => {
          if (details.dataset.populated === 'true') return;
          details.dataset.populated = 'true';
          for (const child of children) {
            if (treeState.renderedNodes >= TREE_NODE_LIMIT) {
              appendTreeLimit(childContainer, treeState);
              break;
            }
            const rendered = treeNode(child, query, depth + 1, treeState);
            if (parseEmbedded.checked && child === node.embeddedJson) rendered.classList.add('embedded');
            childContainer.append(rendered);
          }
        };
        details.addEventListener('toggle', () => { if (details.open) populate(); });
        details.append(heading, childContainer);
        if (details.open) populate();
        return details;
      }
      const row = makeElement('div', 'node-row');
      appendNodeCells(row, node);
      return row;
    }

    function collect(node, target) {
      target.push(node);
      for (const child of visibleChildren(node)) collect(child, target);
    }

    function renderTree(query) {
      if (!matches(displayDocument.root, query)) {
        content.replaceChildren(makeElement('div', 'empty', 'No path, value, or type matches this search.'));
        summary.textContent = '0 matches';
        return;
      }
      const nodes = [];
      collect(displayDocument.root, nodes);
      const matchesCount = query ? nodes.filter(node => [node.path, node.key, node.displayValue, node.type].join('\\n').toLocaleLowerCase().includes(query)).length : nodes.length;
      const treeState = { renderedNodes: 0, limitNoticeShown: false };
      content.replaceChildren(treeNode(displayDocument.root, query, 0, treeState));
      summary.textContent = matchesCount > TREE_NODE_LIMIT
        ? 'Tree shows up to ' + TREE_NODE_LIMIT.toLocaleString() + ' of ' + matchesCount.toLocaleString() + ' nodes · refine search'
        : matchesCount + (matchesCount === 1 ? ' node' : ' nodes');
    }

    function renderTable(query) {
      const nodes = [];
      collect(displayDocument.root, nodes);
      const filtered = nodes.filter(node => !query || [node.path, node.key, node.displayValue, node.type].join('\\n').toLocaleLowerCase().includes(query));
      if (filtered.length === 0) {
        content.replaceChildren(makeElement('div', 'empty', 'No path, value, or type matches this search.'));
        summary.textContent = '0 matches';
        return;
      }
      const table = makeElement('table');
      const head = makeElement('thead');
      const heading = makeElement('tr');
      for (const label of ['Path', 'Value', 'Type', '']) heading.append(makeElement('th', '', label));
      head.append(heading);
      const body = makeElement('tbody');
      const visibleRows = filtered.slice(0, TABLE_ROW_LIMIT);
      for (const node of visibleRows) {
        const row = makeElement('tr');
        row.append(
          makeElement('td', 'path', node.path),
          makeElement('td', 'value', node.displayValue),
          makeElement('td', '', node.type)
        );
        const action = makeElement('td');
        action.append(copyButton(node));
        row.append(action);
        body.append(row);
      }
      table.append(head, body);
      content.replaceChildren(table);
      summary.textContent = filtered.length > TABLE_ROW_LIMIT
        ? 'Showing ' + TABLE_ROW_LIMIT.toLocaleString() + ' of ' + filtered.length.toLocaleString() + ' rows · refine search'
        : filtered.length + (filtered.length === 1 ? ' row' : ' rows');
    }

    function renderJson() {
      const jsonText = parseEmbedded.checked && displayDocument.plainJsonTextWithEmbedded
        ? displayDocument.plainJsonTextWithEmbedded
        : displayDocument.plainJsonText;
      const json = makeElement('pre', '', jsonText);
      json.tabIndex = 0;
      content.replaceChildren(json);
      summary.textContent = new Blob([jsonText]).size.toLocaleString() + ' bytes';
    }

    function saveUiState() {
      vscode.setState({ mode: activeMode, parseEmbedded: parseEmbedded.checked });
    }

    function requestEmbeddedParsing() {
      if (!displayDocument || !parseEmbedded.checked ||
          displayDocument.embeddedJsonIncluded === true || embeddedParsePending) {
        return;
      }
      embeddedParsePending = true;
      parseEmbedded.disabled = true;
      summary.textContent = 'Parsing JSON strings…';
      vscode.postMessage({ type: 'parseEmbedded' });
    }

    function showCopiedToast() {
      clearTimeout(toastTimer);
      toast.classList.add('visible');
      toastTimer = setTimeout(() => toast.classList.remove('visible'), 1200);
    }

    function render() {
      document.querySelectorAll('.mode').forEach(button => {
        const selected = button.dataset.mode === activeMode;
        button.classList.toggle('active', selected);
        button.setAttribute('aria-selected', String(selected));
      });
      parseEmbedded.disabled = embeddedParsePending;
      search.disabled = activeMode === 'raw';
      if (!displayDocument) return;
      const query = search.value.trim().toLocaleLowerCase();
      if (activeMode === 'tree') renderTree(query);
      else if (activeMode === 'table') renderTable(query);
      else renderJson();
    }

    document.querySelector('.modes').addEventListener('click', event => {
      const button = event.target.closest('[data-mode]');
      if (!button) return;
      activeMode = button.dataset.mode;
      saveUiState();
      render();
      requestEmbeddedParsing();
    });
    search.addEventListener('input', () => { saveUiState(); render(); });
    parseEmbedded.addEventListener('change', () => {
      saveUiState();
      render();
      requestEmbeddedParsing();
    });
    content.addEventListener('click', event => {
      const button = event.target.closest('.copy');
      if (!button) return;
      event.preventDefault();
      event.stopPropagation();
      vscode.postMessage({ type: 'copy', value: copyValues.get(button) });
    });
    window.addEventListener('message', event => {
      const message = event.data;
      if (!message) return;
      if (message.type === 'document') {
        displayDocument = message.document;
        embeddedParsePending = false;
        origin.textContent = message.origin;
        render();
        requestEmbeddedParsing();
        return;
      }
      if (message.type === 'embeddedParseFailed') {
        embeddedParsePending = false;
        parseEmbedded.checked = false;
        saveUiState();
        render();
        return;
      }
      if (message.type === 'copySucceeded') {
        showCopiedToast();
        return;
      }
      if (message.type === 'copyFailed') {
        clearTimeout(toastTimer);
        toast.classList.remove('visible');
      }
    });

    render();
    vscode.postMessage({ type: 'ready' });
  </script>
</body>
</html>`;
}

module.exports = { renderViewerDocument };
