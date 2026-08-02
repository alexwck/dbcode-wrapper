'use strict';

const {
  findApprovedCandidate,
  validateApprovedHistory,
  validateInstalledReleaseSet
} = require('./approved-release-set');

const CACHE_TTL_MS = 24 * 60 * 60 * 1000;
const REMINDER_DELAY_MS = 3 * 24 * 60 * 60 * 1000;
const VSCODIUM_METADATA_URL = 'https://api.github.com/repos/VSCodium/vscodium/releases/latest';
const CODE_OSS_METADATA_URL = 'https://api.github.com/repos/microsoft/vscode/releases/latest';
const DBCODE_METADATA_URL = 'https://open-vsx.org/api/dbcode/dbcode';
const VSCODIUM_RELEASE_PREFIX = 'https://github.com/VSCodium/vscodium/releases/tag/';
const CODE_OSS_RELEASE_PREFIX = 'https://github.com/microsoft/vscode/releases/tag/';
const DBCODE_CHANGELOG_PREFIX = 'https://dbcode.io/docs/changelog/';

function requireNonEmptyString(value, label) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`${label} is missing.`);
  }
  return value.trim();
}

function requireTimestamp(value, label) {
  const timestamp = requireNonEmptyString(value, label);
  if (!Number.isFinite(Date.parse(timestamp))) {
    throw new Error(`${label} is invalid.`);
  }
  return timestamp;
}

function versionParts(version) {
  const normalized = requireNonEmptyString(version, 'Version').replace(/^v/, '');
  if (!/^\d+(?:\.\d+)*$/.test(normalized)) {
    throw new Error(`Unsupported version: ${version}`);
  }
  return normalized.split('.').map(part => Number.parseInt(part, 10));
}

function compareVersions(left, right) {
  const leftParts = versionParts(left);
  const rightParts = versionParts(right);
  const length = Math.max(leftParts.length, rightParts.length);
  for (let index = 0; index < length; index++) {
    const difference = (leftParts[index] ?? 0) - (rightParts[index] ?? 0);
    if (difference !== 0) {
      return difference > 0 ? 1 : -1;
    }
  }
  return 0;
}

function normalizeOfficialGithubRelease(payload, label, releasePrefix) {
  if (!payload || typeof payload !== 'object' || payload.draft !== false || payload.prerelease !== false) {
    throw new Error(`The official ${label} metadata is not a stable published release.`);
  }
  const version = requireNonEmptyString(payload.tag_name, `${label} version`);
  versionParts(version);
  const releaseNotesUrl = requireNonEmptyString(payload.html_url, `${label} release notes`);
  if (releaseNotesUrl !== `${releasePrefix}${version}`) {
    throw new Error(`The official ${label} release-notes URL is invalid.`);
  }
  return {
    version,
    publishedAt: requireTimestamp(payload.published_at, `${label} publication date`),
    releaseNotesUrl
  };
}

function normalizeVscodiumRelease(payload) {
  return normalizeOfficialGithubRelease(payload, 'VSCodium', VSCODIUM_RELEASE_PREFIX);
}

function normalizeCodeOssRelease(payload) {
  return normalizeOfficialGithubRelease(payload, 'Code OSS', CODE_OSS_RELEASE_PREFIX);
}

function normalizeOpenVsxRecord(payload) {
  if (
    !payload ||
    typeof payload !== 'object' ||
    payload.namespace !== 'dbcode' ||
    payload.name !== 'dbcode' ||
    payload.verified !== true ||
    payload.preRelease !== false ||
    payload.deprecated !== false
  ) {
    throw new Error('The official DBCode Open VSX record is not a verified stable release.');
  }
  const version = requireNonEmptyString(payload.version, 'DBCode version');
  versionParts(version);
  return {
    version,
    publishedAt: requireTimestamp(payload.timestamp, 'DBCode publication date'),
    releaseNotesUrl: `${DBCODE_CHANGELOG_PREFIX}${version}`
  };
}

function normalizeCachedRelease(release, label, acceptsReleaseNotesUrl) {
  if (!release || typeof release !== 'object') {
    throw new Error(`${label} cached metadata is missing.`);
  }
  const version = requireNonEmptyString(release.version, `${label} cached version`);
  versionParts(version);
  const releaseNotesUrl = requireNonEmptyString(release.releaseNotesUrl, `${label} cached release notes`);
  if (!acceptsReleaseNotesUrl(releaseNotesUrl, version)) {
    throw new Error(`${label} cached release-notes URL is invalid.`);
  }
  return {
    version,
    publishedAt: requireTimestamp(release.publishedAt, `${label} cached publication date`),
    releaseNotesUrl
  };
}

function normalizeCachedAvailable(available) {
  return {
    vscodium: normalizeCachedRelease(
      available?.vscodium,
      'VSCodium',
      (value, version) => value === `${VSCODIUM_RELEASE_PREFIX}${version}`
    ),
    codeOss: normalizeCachedRelease(
      available?.codeOss,
      'Code OSS',
      (value, version) => value === `${CODE_OSS_RELEASE_PREFIX}${version}`
    ),
    dbcode: normalizeCachedRelease(
      available?.dbcode,
      'DBCode',
      (value, version) => value === `${DBCODE_CHANGELOG_PREFIX}${version}`
    )
  };
}

function releaseTuple({ vscodiumVersion, codeOssVersion, dbcodeVersion }) {
  const tuple = {
    vscodiumVersion: requireNonEmptyString(vscodiumVersion, 'VSCodium version'),
    codeOssVersion: requireNonEmptyString(codeOssVersion, 'Code OSS version'),
    dbcodeVersion: requireNonEmptyString(dbcodeVersion, 'DBCode version')
  };
  versionParts(tuple.vscodiumVersion);
  versionParts(tuple.codeOssVersion);
  versionParts(tuple.dbcodeVersion);
  return tuple;
}

function candidateKey(candidate) {
  const tuple = releaseTuple(candidate);
  return `vscodium@${tuple.vscodiumVersion}|code-oss@${tuple.codeOssVersion}|dbcode@${tuple.dbcodeVersion}`;
}

function normalizeState(state = {}) {
  const storedReminder = state.reminder &&
    typeof state.reminder.candidateKey === 'string' &&
    typeof state.reminder.after === 'string'
    ? state.reminder
    : undefined;
  const reminder = storedReminder
    ? {
        candidateKey: storedReminder.candidateKey,
        readyToInstall: storedReminder.readyToInstall === true,
        after: Number.isFinite(Date.parse(storedReminder.after))
          ? storedReminder.after
          : new Date(0).toISOString()
      }
    : undefined;
  return {
    lastPromptedCandidate: typeof state.lastPromptedCandidate === 'string' ? state.lastPromptedCandidate : undefined,
    lastPromptedAt: typeof state.lastPromptedAt === 'string' ? state.lastPromptedAt : undefined,
    lastPromptedReadyToInstall: typeof state.lastPromptedReadyToInstall === 'boolean' ? state.lastPromptedReadyToInstall : undefined,
    reminder,
    skippedCandidates: Array.isArray(state.skippedCandidates)
      ? [...new Set(state.skippedCandidates.filter(value => typeof value === 'string'))]
      : []
  };
}

function releaseView(installedRelease, availableRelease, updateAvailable, readyToInstall) {
  const reviewedRelease = updateAvailable ? availableRelease : installedRelease;
  return {
    installedVersion: installedRelease.version,
    installedPublishedAt: installedRelease.publishedAt,
    installedReleaseNotesUrl: installedRelease.releaseNotesUrl,
    availableVersion: reviewedRelease.version,
    availablePublishedAt: reviewedRelease.publishedAt,
    availableReleaseNotesUrl: reviewedRelease.releaseNotesUrl,
    updateAvailable,
    readiness: updateAvailable ? (readyToInstall ? 'Ready to install' : 'Not tested') : 'Current'
  };
}

function installedCodeOssRelease(installed) {
  return {
    version: installed.host.codeOssVersion,
    publishedAt: installed.host.codeOssPublishedAt,
    releaseNotesUrl: installed.host.codeOssReleaseNotesUrl
  };
}

function shouldPromptForCandidate(state, key, readyToInstall, now) {
  if (state.skippedCandidates.includes(key)) {
    return false;
  }
  if (state.reminder?.candidateKey === key && state.reminder.readyToInstall === readyToInstall) {
    const reminderAt = Date.parse(state.reminder.after);
    return Number.isFinite(reminderAt) && now >= reminderAt;
  }
  return state.lastPromptedCandidate !== key || state.lastPromptedReadyToInstall !== readyToInstall;
}

function deriveStatus({ installed, available, approvedReleaseSets = [], state = {}, source = 'network', now = Date.now() }) {
  validateInstalledReleaseSet(installed);
  if (source === 'offline' || source === 'invalid' || !available?.vscodium || !available?.codeOss || !available?.dbcode) {
    return {
      kind: source === 'invalid' ? 'invalid' : 'offline',
      source,
      installed,
      updatesAvailable: false,
      readyToInstall: false,
      shouldPrompt: false
    };
  }

  const vscodiumUpdate = compareVersions(available.vscodium.version, installed.host.version) > 0;
  const installedCodeOss = installedCodeOssRelease(installed);
  const availableCodeOss = available.codeOss;
  const codeOssUpdate = compareVersions(availableCodeOss.version, installedCodeOss.version) > 0;
  const dbcodeUpdate = compareVersions(available.dbcode.version, installed.dbcode.version) > 0;
  const updatesAvailable = vscodiumUpdate || codeOssUpdate || dbcodeUpdate;
  const candidate = releaseTuple({
    vscodiumVersion: vscodiumUpdate ? available.vscodium.version : installed.host.version,
    codeOssVersion: codeOssUpdate ? availableCodeOss.version : installedCodeOss.version,
    dbcodeVersion: dbcodeUpdate ? available.dbcode.version : installed.dbcode.version
  });
  const key = candidateKey(candidate);
  const approvedCandidate = updatesAvailable
    ? findApprovedCandidate(approvedReleaseSets, installed, candidate)
    : undefined;
  const readyToInstall = Boolean(approvedCandidate);
  const cleanState = normalizeState(state);
  return {
    kind: updatesAvailable ? 'update-available' : 'current',
    source,
    installed,
    candidateKey: key,
    approvedReleaseSetId: approvedCandidate?.id,
    updatesAvailable,
    readyToInstall,
    shouldPrompt: updatesAvailable && shouldPromptForCandidate(cleanState, key, readyToInstall, now),
    vscodium: releaseView(installed.host, available.vscodium, vscodiumUpdate, readyToInstall),
    codeOss: releaseView(installedCodeOss, availableCodeOss, codeOssUpdate, readyToInstall),
    dbcode: releaseView(installed.dbcode, available.dbcode, dbcodeUpdate, readyToInstall)
  };
}

function recordPrompt(state, status, now = Date.now()) {
  if (!status?.updatesAvailable || !status.candidateKey) {
    return normalizeState(state);
  }
  const next = normalizeState(state);
  if (next.reminder?.candidateKey === status.candidateKey) {
    next.reminder = undefined;
  }
  return {
    ...next,
    lastPromptedCandidate: status.candidateKey,
    lastPromptedAt: new Date(now).toISOString(),
    lastPromptedReadyToInstall: status.readyToInstall === true
  };
}

function applyDecision(state, decision, status, now = Date.now()) {
  const next = normalizeState(state);
  if (!status?.updatesAvailable || !status.candidateKey) {
    return next;
  }
  if (decision === 'review') {
    next.reminder = undefined;
    return next;
  }
  if (decision === 'remind') {
    next.reminder = {
      candidateKey: status.candidateKey,
      readyToInstall: status.readyToInstall === true,
      after: new Date(now + REMINDER_DELAY_MS).toISOString()
    };
    return next;
  }
  if (decision === 'skip') {
    next.skippedCandidates = [...new Set([...next.skippedCandidates, status.candidateKey])];
    next.reminder = undefined;
    return next;
  }
  throw new Error(`Unsupported update decision: ${decision}`);
}

function shouldUseCache(cache, now = Date.now()) {
  const checkedAt = Date.parse(cache?.checkedAt);
  return Number.isFinite(checkedAt) && now >= checkedAt && now - checkedAt <= CACHE_TTL_MS;
}

function normalizeStoredState(value) {
  const state = value && typeof value === 'object' ? value : {};
  let metadataCache;
  try {
    const checkedAt = requireTimestamp(state.metadataCache?.checkedAt, 'Cached metadata check date');
    metadataCache = { checkedAt, available: normalizeCachedAvailable(state.metadataCache.available) };
  } catch {
    metadataCache = undefined;
  }
  return {
    schemaVersion: 2,
    decisions: normalizeState(state.decisions),
    lastCheckAt: typeof state.lastCheckAt === 'string' ? state.lastCheckAt : undefined,
    lastCheckResult: ['success', 'offline', 'invalid'].includes(state.lastCheckResult) ? state.lastCheckResult : undefined,
    metadataCache
  };
}

function createReleaseStatusService({
  installed,
  approvedReleaseSets = [],
  loadApprovedReleaseSets = async () => approvedReleaseSets,
  loadState,
  saveState,
  fetchJson,
  now = Date.now
}) {
  if (typeof loadApprovedReleaseSets !== 'function' || typeof loadState !== 'function' || typeof saveState !== 'function' || typeof fetchJson !== 'function') {
    throw new Error('Release-status storage and metadata ports are required.');
  }

  async function currentApprovedReleaseSets() {
    try {
      const loaded = await loadApprovedReleaseSets();
      const history = Array.isArray(loaded)
        ? { schema_version: 2, approved_release_sets: loaded }
        : loaded;
      validateApprovedHistory(history);
      return history.approved_release_sets;
    } catch {
      return [];
    }
  }

  async function persistCheck(state, result, checkedAt, available) {
    const next = {
      ...state,
      schemaVersion: 2,
      lastCheckAt: checkedAt,
      lastCheckResult: result
    };
    if (available) {
      next.metadataCache = { checkedAt, available };
    }
    await saveState(next);
    return next;
  }

  async function check({ force = false } = {}) {
    const checkedAtMs = now();
    let state = normalizeStoredState(await loadState());
    const approvedCandidates = await currentApprovedReleaseSets();
    if (!force && state.metadataCache && shouldUseCache(state.metadataCache, checkedAtMs)) {
      return deriveStatus({
        installed,
        available: state.metadataCache.available,
        approvedReleaseSets: approvedCandidates,
        state: state.decisions,
        source: 'cache',
        now: checkedAtMs
      });
    }
    if (!force && state.lastCheckAt && state.lastCheckResult !== 'success' && shouldUseCache({ checkedAt: state.lastCheckAt }, checkedAtMs)) {
      return deriveStatus({
        installed,
        available: undefined,
        approvedReleaseSets: approvedCandidates,
        state: state.decisions,
        source: state.lastCheckResult,
        now: checkedAtMs
      });
    }

    const checkedAt = new Date(checkedAtMs).toISOString();
    let vscodiumPayload;
    let codeOssPayload;
    let dbcodePayload;
    try {
      [vscodiumPayload, codeOssPayload, dbcodePayload] = await Promise.all([
        fetchJson(VSCODIUM_METADATA_URL),
        fetchJson(CODE_OSS_METADATA_URL),
        fetchJson(DBCODE_METADATA_URL)
      ]);
    } catch {
      state = await persistCheck(state, 'offline', checkedAt);
      return deriveStatus({ installed, available: undefined, approvedReleaseSets: approvedCandidates, state: state.decisions, source: 'offline', now: checkedAtMs });
    }

    let available;
    try {
      available = {
        vscodium: normalizeVscodiumRelease(vscodiumPayload),
        codeOss: normalizeCodeOssRelease(codeOssPayload),
        dbcode: normalizeOpenVsxRecord(dbcodePayload)
      };
    } catch {
      state = await persistCheck(state, 'invalid', checkedAt);
      return deriveStatus({ installed, available: undefined, approvedReleaseSets: approvedCandidates, state: state.decisions, source: 'invalid', now: checkedAtMs });
    }

    state = await persistCheck(state, 'success', checkedAt, available);
    return deriveStatus({ installed, available, approvedReleaseSets: approvedCandidates, state: state.decisions, source: 'network', now: checkedAtMs });
  }

  async function markPrompted(status) {
    const state = normalizeStoredState(await loadState());
    state.decisions = recordPrompt(state.decisions, status, now());
    await saveState(state);
    return state.decisions;
  }

  async function decide(decision, status) {
    const state = normalizeStoredState(await loadState());
    state.decisions = applyDecision(state.decisions, decision, status, now());
    await saveState(state);
    return state.decisions;
  }

  return { check, decide, markPrompted };
}

module.exports = {
  CODE_OSS_METADATA_URL,
  DBCODE_METADATA_URL,
  VSCODIUM_METADATA_URL,
  createReleaseStatusService
};
