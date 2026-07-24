'use strict';

const crypto = require('node:crypto');
const { isDeepStrictEqual } = require('node:util');

const NORMALIZATION = 'Unicode NFC, collapsed whitespace, case-sensitive code-point sort';

function normalizeText(value, field) {
  if (typeof value !== 'string') {
    throw new TypeError(`${field} must be text.`);
  }
  const normalized = value.normalize('NFC').replace(/\s+/g, ' ').trim();
  if (!normalized) {
    throw new Error(`${field} must not be empty.`);
  }
  return normalized;
}

function digestLines(lines) {
	return crypto.createHash('sha256').update(`${lines.join('\n')}\n`, 'utf8').digest('hex');
}

function compareCodePointText(left, right) {
	const leftPoints = Array.from(left, character => character.codePointAt(0));
	const rightPoints = Array.from(right, character => character.codePointAt(0));
	const sharedLength = Math.min(leftPoints.length, rightPoints.length);
	for (let index = 0; index < sharedLength; index += 1) {
		if (leftPoints[index] !== rightPoints[index]) {
			return leftPoints[index] - rightPoints[index];
		}
	}
	return leftPoints.length - rightPoints.length;
}

function createConnectionCatalogueSnapshot({ extensionId, extensionVersion, sections }) {
  const id = normalizeText(extensionId, 'Extension ID');
  const version = normalizeText(extensionVersion, 'Extension version');
  if (!Array.isArray(sections) || sections.length === 0) {
    throw new Error('The rendered connection catalogue must contain counted sections.');
  }

  const normalizedSections = sections.map((section, index) => {
    const title = normalizeText(section?.title, `Section ${index + 1} title`);
    if (!Number.isSafeInteger(section?.declaredCount) || section.declaredCount < 1) {
      throw new Error(`Section ${title} must declare a positive item count.`);
    }
    if (!Array.isArray(section.labels)) {
      throw new Error(`Section ${title} must expose rendered connection labels.`);
    }
    const labels = section.labels.map((label, labelIndex) => normalizeText(label, `${title} item ${labelIndex + 1}`));
    if (labels.length !== section.declaredCount) {
      throw new Error(`Section ${title} declares ${section.declaredCount} items but rendered ${labels.length}.`);
    }
    return { title, declaredCount: section.declaredCount, labels };
  });

  const sectionTitles = normalizedSections.map(section => section.title);
  if (new Set(sectionTitles).size !== sectionTitles.length) {
    throw new Error('The rendered connection catalogue contains a duplicate section title.');
  }

  const labels = normalizedSections.flatMap(section => section.labels);
  if (new Set(labels).size !== labels.length) {
    throw new Error('The rendered connection catalogue contains a duplicate connection label.');
  }
	const sortedLabels = [...labels].sort(compareCodePointText);
  const declaredTotal = normalizedSections.reduce((total, section) => total + section.declaredCount, 0);

  return {
    source: 'rendered-new-connection-picker',
    extension: `${id}@${version}`,
    normalization: NORMALIZATION,
    section_count: normalizedSections.length,
    item_count: labels.length,
    declared_section_item_total: declaredTotal,
    sorted_label_sha256: digestLines(sortedLabels),
    ordered_section_shape_sha256: digestLines(normalizedSections.map(section => `${section.title}\t${section.declaredCount}`)),
    raw_labels_committed: false
  };
}

function verifyConnectionCatalogueSnapshot(actual, expected) {
	if (!isDeepStrictEqual(actual, expected)) {
    throw new Error('The rendered DBCode connection catalogue does not match the reviewed catalogue snapshot. Review the complete host and DBCode release pair before approval.');
  }
  return actual;
}

module.exports = {
  NORMALIZATION,
  createConnectionCatalogueSnapshot,
  verifyConnectionCatalogueSnapshot
};
