#!/usr/bin/env node

import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);
const {
  createConnectionCatalogueSnapshot,
  verifyConnectionCatalogueSnapshot
} = require('../host/qa/connection-catalogue-contract.cjs');

const catalogue = {
  extensionId: 'vendor.database-client',
  extensionVersion: '2.4.0',
  sections: [
    { title: 'Hosted systems', declaredCount: 2, labels: [' Example Cloud ', 'Example SQL'] },
    { title: 'File formats', declaredCount: 1, labels: ['Example File'] }
  ]
};

test('a rendered catalogue becomes a deterministic digest-only snapshot', () => {
  const snapshot = createConnectionCatalogueSnapshot(catalogue);

  assert.deepEqual(snapshot, {
    source: 'rendered-new-connection-picker',
    extension: 'vendor.database-client@2.4.0',
    normalization: 'Unicode NFC, collapsed whitespace, case-sensitive code-point sort',
    section_count: 2,
    item_count: 3,
    declared_section_item_total: 3,
    sorted_label_sha256: 'cdca64c5055eecdf26885e9bf63cf814cb7c596777baead27ed668f34f267700',
    ordered_section_shape_sha256: '15d525a703f378476bb4b74d0aff03ddbd4c925f2273bc4ab242827ad5fead83',
    raw_labels_committed: false
  });
});

test('section count drift and duplicate catalogue labels fail closed', () => {
  assert.throws(
    () => createConnectionCatalogueSnapshot({
      ...catalogue,
      sections: [{ title: 'Hosted systems', declaredCount: 3, labels: ['One', 'Two'] }]
    }),
    /declares 3 items but rendered 2/i
  );

  assert.throws(
    () => createConnectionCatalogueSnapshot({
      ...catalogue,
      sections: [
        { title: 'First', declaredCount: 1, labels: ['Same target'] },
        { title: 'Second', declaredCount: 1, labels: ['Same target'] }
      ]
    }),
    /duplicate connection label/i
  );
});

test('catalogue labels use the documented Unicode code-point order', () => {
  const snapshot = createConnectionCatalogueSnapshot({
    extensionId: 'vendor.database-client',
    extensionVersion: '2.4.0',
    sections: [{ title: 'Unicode', declaredCount: 2, labels: ['😀', '\uE000'] }]
  });
  const expectedDigest = createHash('sha256').update('\uE000\n😀\n', 'utf8').digest('hex');

  assert.equal(snapshot.sorted_label_sha256, expectedDigest);
});

test('verification requires the exact reviewed extension and catalogue fingerprint', () => {
  const expected = createConnectionCatalogueSnapshot(catalogue);
  assert.deepEqual(verifyConnectionCatalogueSnapshot(expected, expected), expected);

  assert.throws(
    () => verifyConnectionCatalogueSnapshot(
      { ...expected, extension: 'vendor.database-client@2.5.0' },
      expected
    ),
    /reviewed catalogue snapshot/i
  );
  assert.throws(
    () => verifyConnectionCatalogueSnapshot(
      { ...expected, item_count: 4 },
      expected
    ),
    /reviewed catalogue snapshot/i
  );
});
