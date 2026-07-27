'use strict';

const fs = require('node:fs');
const path = require('node:path');

const GIT_COMMIT_PATTERN = /^[0-9a-f]{40}$/;
const SHA256_PATTERN = /^[0-9a-f]{64}$/;
const COMPILED_HOST_INPUT_PATTERN = /^compiled-host-[0-9a-f]{64}$/;
const VERSION_PATTERN = /^\d+(?:\.\d+)*(?:[-+][0-9A-Za-z.-]+)?$/;
const PROMPT_FREE_VERIFICATION_CHECKS = [
  'app_artifact_digest',
  'apple_silicon_only',
  'complete_same_mac_acceptance',
  'designated_requirement',
  'disk_image_integrity',
  'exact_top_level_contents',
  'external_runtime_not_bundled',
  'host_only_content_scan',
  'install_guide',
  'mounted_read_only',
  'nested_code_signatures',
  'private_data_absent',
  'source_tag',
  'upstream_notices'
];
const PREPARED_MEMBER_NAMES = new Set([
  'app',
  'build_manifest',
  'release_lock',
  'user_data',
  'extensions',
  'shared_data',
  'proof'
]);

function fail(message) {
  throw new Error(message);
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function requireObject(value, label) {
  if (!isObject(value)) {
    fail(`${label} is missing or invalid.`);
  }
  return value;
}

function requireString(value, label) {
  if (typeof value !== 'string' || value.trim() === '') {
    fail(`${label} is missing.`);
  }
  return value.trim();
}

function requirePattern(value, pattern, label) {
  const text = requireString(value, label);
  if (!pattern.test(text)) {
    fail(`${label} is invalid.`);
  }
  return text;
}

function requireTimestamp(value, label) {
  const timestamp = requireString(value, label);
  if (!Number.isFinite(Date.parse(timestamp))) {
    fail(`${label} is invalid.`);
  }
  return timestamp;
}

function requirePositiveInteger(value, label) {
  if (!Number.isInteger(value) || value <= 0) {
    fail(`${label} is invalid.`);
  }
  return value;
}

function requireVersion(value, label) {
  return requirePattern(value, VERSION_PATTERN, label);
}

function requireSha256(value, label) {
  return requirePattern(value, SHA256_PATTERN, label);
}

function requireCommit(value, label) {
  return requirePattern(value, GIT_COMMIT_PATTERN, label);
}

function requireTarget(target, label = 'Release target') {
  requireObject(target, label);
  if (target.platform !== 'darwin' || target.architecture !== 'arm64') {
    fail(`${label} is unsupported.`);
  }
  return target;
}

function hasCanonicalSourceSetId(sourceSetId, codeOssVersion, dbcodeVersion) {
  if (
    typeof sourceSetId !== 'string' ||
    !VERSION_PATTERN.test(codeOssVersion ?? '') ||
    !VERSION_PATTERN.test(dbcodeVersion ?? '')
  ) {
    return false;
  }
  const prefix = `code-oss-${codeOssVersion}-dbcode-${dbcodeVersion}-source-`;
  return sourceSetId.startsWith(prefix) && SHA256_PATTERN.test(sourceSetId.slice(prefix.length));
}

function requireCanonicalIdentity(record) {
  if (!hasCanonicalSourceSetId(record.source_set_id, record.host?.code_oss_tag, record.dbcode?.version)) {
    fail('Approved Release Set source identity does not match its host and DBCode pair.');
  }
  const expectedId = `${record.source_set_id}-artifact-${record.manifest?.artifact_sha256}`;
  if (record.id !== expectedId) {
    fail('Approved Release Set artifact identity is invalid.');
  }
}

function validateRelativeMemberPath(value, label = 'Prepared release-set member path') {
  const relativePath = requireString(value, label);
  if (
    path.isAbsolute(relativePath) ||
    relativePath.includes('\0') ||
    relativePath.includes('\\') ||
    relativePath.split('/').some(part => part === '' || part === '.' || part === '..')
  ) {
    fail(`${label} is unsafe.`);
  }
  return relativePath;
}

function validatePreparedReleaseSet(record) {
  requireObject(record, 'Prepared release-set record');
  if (record.schema_version !== 1) {
    fail('Prepared release-set schema is unsupported.');
  }
  if (!['current', 'candidate'].includes(record.role)) {
    fail('Prepared release-set role is invalid.');
  }
  requireTimestamp(record.prepared_at_utc, 'Prepared release-set timestamp');
  const release = requireObject(record.release, 'Prepared release identity');
  requireString(release.release_set_id, 'Prepared release-set ID');
  requireString(release.source_set_id, 'Prepared source-set ID');
  requireCommit(record.source?.repository_revision, 'Prepared source revision');
  requireTarget(record.target, 'Prepared release target');
  requireSha256(record.host?.app_sha256, 'Prepared app digest');
  requireSha256(record.host?.build_manifest_sha256, 'Prepared build-manifest digest');
  requireVersion(record.host?.code_oss_version, 'Prepared Code OSS version');
  if (record.dbcode?.id !== 'dbcode.dbcode') {
    fail('Prepared DBCode identity is invalid.');
  }
  requireVersion(record.dbcode?.version, 'Prepared DBCode version');
  requireSha256(record.dbcode?.vsix_sha256, 'Prepared DBCode package digest');
  requireSha256(record.dbcode?.signature_archive_sha256, 'Prepared DBCode signature digest');
  requirePositiveInteger(record.profile?.schema_version, 'Prepared profile schema');
  requireSha256(record.profile?.user_data_sha256, 'Prepared user-data digest');
  requireSha256(record.profile?.source_extensions_sha256, 'Prepared source-extension digest');
  requireSha256(record.profile?.extensions_sha256, 'Prepared extension digest');
  requireSha256(record.profile?.shared_data_sha256, 'Prepared shared-data digest');
  if (!Array.isArray(record.profile?.installed_extensions) || record.profile.installed_extensions.length === 0) {
    fail('Prepared extension inventory is missing.');
  }
  if (!record.profile.installed_extensions.every(value => typeof value === 'string' && value.includes('@'))) {
    fail('Prepared extension inventory is invalid.');
  }
  if (!Array.isArray(record.profile?.restored_signed_payloads)) {
    fail('Prepared restored-payload record is invalid.');
  }
  const paths = requireObject(record.paths, 'Prepared release-set paths');
  for (const member of ['app', 'build_manifest', 'release_lock', 'user_data', 'extensions', 'shared_data']) {
    validateRelativeMemberPath(paths[member], `Prepared ${member} path`);
  }
  if (record.role === 'candidate') {
    requireSha256(record.evidence?.proof_sha256, 'Prepared proof digest');
    validateRelativeMemberPath(paths.proof, 'Prepared proof path');
  } else if (paths.proof !== undefined) {
    validateRelativeMemberPath(paths.proof, 'Prepared proof path');
  }
  return record;
}

function validateLegacyApprovedRecord(record) {
  if (record.schema_version !== undefined || record.source_set_id !== undefined || record.approval !== undefined) {
    fail('Legacy approval record mixes incompatible schemas.');
  }
  if (record.compatibility_status !== 'approved') {
    fail('Legacy approval state is invalid.');
  }
  requireCommit(record.source_commit, 'Legacy approval source revision');
  requireTarget(record.target, 'Legacy approval target');
  requirePositiveInteger(record.profile?.schema_version, 'Legacy profile schema');
  if (record.manifest?.schema_version !== 2) {
    fail('Legacy build-manifest schema is unsupported.');
  }
  requireSha256(record.manifest?.build_manifest_sha256, 'Legacy build-manifest digest');
  requireSha256(record.manifest?.artifact_sha256, 'Legacy artifact digest');
  requireSha256(record.manifest?.shell_patch_revision, 'Legacy shell-patch digest');
  requireSha256(record.manifest?.overlay_sha256, 'Legacy overlay digest');
  if (record.manifest?.packaging_status !== 'built-and-signed') {
    fail('Legacy packaging state is invalid.');
  }
  requireVersion(record.host?.vscodium_tag, 'Legacy VSCodium version');
  requireCommit(record.host?.vscodium_commit, 'Legacy VSCodium revision');
  requireVersion(record.host?.code_oss_tag, 'Legacy Code OSS version');
  requireCommit(record.host?.code_oss_commit, 'Legacy Code OSS revision');
  if (record.dbcode?.id !== 'dbcode.dbcode') {
    fail('Legacy DBCode identity is invalid.');
  }
  requireVersion(record.dbcode?.version, 'Legacy DBCode version');
  requireSha256(record.dbcode?.vsix_sha256, 'Legacy DBCode package digest');
  requireSha256(record.dbcode?.signature_archive_sha256, 'Legacy DBCode signature digest');
  const expectedId = `code-oss-${record.host.code_oss_tag}-dbcode-${record.dbcode.version}`;
  if (record.id !== expectedId) {
    fail('Legacy release-set identity is invalid.');
  }
  return { kind: 'legacy', record };
}

function validateVersionedApprovedRecord(record, { current }) {
  if (record.compatibility_status !== 'approved') {
    fail('Approved Release Set compatibility state is invalid.');
  }
  requireCommit(record.source_commit, 'Approved source revision');
  requireTarget(record.target, 'Approved release target');
  requirePositiveInteger(record.profile?.schema_version, 'Approved profile schema');
  const minimumManifestSchema = current ? 6 : 5;
  if (!Number.isInteger(record.manifest?.schema_version) ||
      record.manifest.schema_version < minimumManifestSchema) {
    fail('Approved build-manifest schema is unsupported.');
  }
  requireSha256(record.manifest?.build_manifest_sha256, 'Approved build-manifest digest');
  requireSha256(record.manifest?.candidate_manifest_sha256, 'Approved candidate-manifest digest');
  requireSha256(record.manifest?.approval_attestation_sha256, 'Approved attestation digest');
  requireSha256(record.manifest?.artifact_sha256, 'Approved artifact digest');
  requireSha256(record.manifest?.shell_patch_revision, 'Approved shell-patch digest');
  requireSha256(record.manifest?.overlay_sha256, 'Approved overlay digest');
  if (current) {
    requireSha256(record.manifest?.source_snapshot_sha256, 'Approved source-snapshot digest');
    requirePattern(
      record.manifest?.compiled_host_input_id,
      COMPILED_HOST_INPUT_PATTERN,
      'Approved compiled-host input ID'
    );
  }
  if (record.manifest?.packaging_status !== 'built-and-signed') {
    fail('Approved packaging state is invalid.');
  }
  requireVersion(record.host?.vscodium_tag, 'Approved VSCodium version');
  requireCommit(record.host?.vscodium_commit, 'Approved VSCodium revision');
  requireVersion(record.host?.code_oss_tag, 'Approved Code OSS version');
  requireCommit(record.host?.code_oss_commit, 'Approved Code OSS revision');
  if (record.dbcode?.id !== 'dbcode.dbcode') {
    fail('Approved DBCode identity is invalid.');
  }
  requireVersion(record.dbcode?.version, 'Approved DBCode version');
  requireSha256(record.dbcode?.vsix_sha256, 'Approved DBCode package digest');
  requireSha256(record.dbcode?.signature_archive_sha256, 'Approved DBCode signature digest');
  requireTimestamp(record.approval?.approved_at, 'Approval timestamp');
  requireString(record.approval?.validation_issue, 'Approval validation issue');
  requireSha256(record.approval?.proof_sha256, 'Approval proof digest');
  requireSha256(record.approval?.gate_receipt_sha256, 'Approval gate-receipt digest');
  if (record.approval?.mode !== undefined) {
    if (record.approval.mode !== 'prompt-free-private-release') {
      fail('Approved release mode is invalid.');
    }
    requireString(record.approval.source_tag, 'Approved source tag');
    requireSha256(record.approval.compatibility_manifest_sha256, 'Approved compatibility-manifest digest');
    requireSha256(record.approval.release_lock_sha256, 'Approved release-lock digest');
    if (record.approval.production_profile_written !== false ||
        record.approval.installed_app_changed !== false) {
      fail('Prompt-free approval must not change the production profile or installed app.');
    }
  }
  requireCanonicalIdentity(record);
  return { kind: current ? 'complete' : 'previous', record };
}

function validateApprovedRecord(record, { allowLegacy = true } = {}) {
  requireObject(record, 'Approved Release Set record');
  if (record.schema_version === 2) {
    return validateVersionedApprovedRecord(record, { current: true });
  }
  if (!allowLegacy) {
    fail('Approved Release Set schema is unsupported.');
  }
  if (record.schema_version === 1) {
    return validateVersionedApprovedRecord(record, { current: false });
  }
  return validateLegacyApprovedRecord(record);
}

function validateApprovedHistory(history) {
  requireObject(history, 'Approved Release Set history');
  if (history.schema_version !== 2 || !Array.isArray(history.approved_release_sets)) {
    fail('Approved Release Set history schema is unsupported.');
  }
  const records = history.approved_release_sets.map(record => validateApprovedRecord(record));
  const ids = records.map(entry => entry.record.id);
  if (new Set(ids).size !== ids.length) {
    fail('Approved Release Set history contains a duplicate identity.');
  }
  return { schemaVersion: 2, records };
}

function validateInstalledReleaseSet(installed) {
  requireObject(installed, 'Installed release-set identity');
  if (installed.schemaVersion !== 1 || !['candidate', 'approved'].includes(installed.compatibilityStatus)) {
    fail('Installed release-set identity is incomplete or invalid.');
  }
  requirePositiveInteger(installed.profileSchemaVersion, 'Installed profile schema');
  requireTarget(installed.target, 'Installed release-set identity target');
  requireVersion(installed.host?.version, 'Installed VSCodium version');
  requireVersion(installed.host?.codeOssVersion, 'Installed Code OSS version');
  requireCommit(installed.host?.vscodiumCommit, 'Installed VSCodium revision');
  requireCommit(installed.host?.codeOssCommit, 'Installed Code OSS revision');
  requireTimestamp(installed.host?.publishedAt, 'Installed VSCodium publication date');
  const hostNotes = requireString(installed.host?.releaseNotesUrl, 'Installed VSCodium release notes');
  if (hostNotes !== `https://github.com/VSCodium/vscodium/releases/tag/${installed.host.version}`) {
    fail('Installed VSCodium release notes are invalid.');
  }
  requireTimestamp(installed.host?.codeOssPublishedAt, 'Installed release-set identity Code OSS publication date');
  const codeOssNotes = requireString(installed.host?.codeOssReleaseNotesUrl, 'Installed release-set identity Code OSS release notes');
  if (codeOssNotes !== `https://github.com/microsoft/vscode/releases/tag/${installed.host.codeOssVersion}`) {
    fail('Installed release-set identity Code OSS release notes are invalid.');
  }
  requireVersion(installed.dbcode?.version, 'Installed DBCode version');
  requireSha256(installed.dbcode?.sha256, 'Installed DBCode digest');
  requireTimestamp(installed.dbcode?.publishedAt, 'Installed DBCode publication date');
  const dbcodeNotes = requireString(installed.dbcode?.releaseNotesUrl, 'Installed DBCode release notes');
  if (dbcodeNotes !== `https://dbcode.io/docs/changelog/${installed.dbcode.version}`) {
    fail('Installed DBCode release notes are invalid.');
  }
  if (!hasCanonicalSourceSetId(installed.sourceSetId, installed.host.codeOssVersion, installed.dbcode.version)) {
    fail('Installed release-set identity source ID is invalid.');
  }
  return installed;
}

function findApprovedCandidate(approvedReleaseSets, installed, candidate) {
  validateInstalledReleaseSet(installed);
  requireObject(candidate, 'Candidate release tuple');
  const vscodiumVersion = requireVersion(candidate.vscodiumVersion, 'Candidate VSCodium version');
  const codeOssVersion = requireVersion(candidate.codeOssVersion, 'Candidate Code OSS version');
  const dbcodeVersion = requireVersion(candidate.dbcodeVersion, 'Candidate DBCode version');
  if (!Array.isArray(approvedReleaseSets)) {
    return undefined;
  }
  return approvedReleaseSets.find(record => {
    try {
      const validated = validateApprovedRecord(record, { allowLegacy: true });
      return validated.kind === 'complete' &&
        record.target.platform === installed.target.platform &&
        record.target.architecture === installed.target.architecture &&
        record.host.vscodium_tag === vscodiumVersion &&
        record.host.code_oss_tag === codeOssVersion &&
        record.dbcode.version === dbcodeVersion;
    } catch {
      return false;
    }
  });
}

function readPlainJsonFile(filePath, label) {
  let fileInfo;
  try {
    fileInfo = fs.lstatSync(filePath);
  } catch {
    fail(`${label} is missing.`);
  }
  if (!fileInfo.isFile() || fileInfo.isSymbolicLink()) {
    fail(`${label} is missing or symlinked.`);
  }
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    fail(`${label} is not valid JSON.`);
  }
}

function resolvePreparedMember(setFile, memberName) {
  if (!PREPARED_MEMBER_NAMES.has(memberName)) {
    fail(`Unknown prepared release-set member: ${memberName}`);
  }
  const record = readPlainJsonFile(setFile, 'Prepared release-set record');
  validatePreparedReleaseSet(record);
  const relativePath = validateRelativeMemberPath(record.paths?.[memberName], `Prepared ${memberName} path`);
  const setRoot = fs.realpathSync(path.dirname(setFile));
  const candidatePath = path.join(setRoot, relativePath);
  let candidateInfo;
  try {
    candidateInfo = fs.lstatSync(candidatePath);
  } catch {
    fail(`Prepared release-set member is missing: ${relativePath}`);
  }
  if (candidateInfo.isSymbolicLink()) {
    fail(`Prepared release-set member is symlinked: ${relativePath}`);
  }
  const resolvedPath = fs.realpathSync(candidatePath);
  const relativeResolvedPath = path.relative(setRoot, resolvedPath);
  if (relativeResolvedPath === '' || relativeResolvedPath.startsWith(`..${path.sep}`) || path.isAbsolute(relativeResolvedPath)) {
    fail(`Prepared release-set member escapes its directory: ${relativePath}`);
  }
  return resolvedPath;
}

function createPromptFreeApprovedRecord({
  compatibility,
  manifest,
  releaseLock,
  acceptance,
  verification,
  attestation,
  compatibilitySha256,
  manifestSha256,
  releaseLockSha256,
  acceptanceSha256,
  verificationSha256,
  attestationSha256
}) {
  requireObject(compatibility, 'Private-release compatibility manifest');
  requireObject(manifest, 'Candidate build manifest');
  requireObject(releaseLock, 'Candidate Release Specification');
  requireObject(acceptance, 'Prompt-free acceptance report');
  requireObject(verification, 'Private-release verification receipt');
  requireObject(attestation, 'Prompt-free approval attestation');
  const compatibilityDigest = requireSha256(
    compatibilitySha256,
    'Private-release compatibility-manifest digest'
  );
  const manifestDigest = requireSha256(manifestSha256, 'Candidate build-manifest digest');
  const lockDigest = requireSha256(releaseLockSha256, 'Candidate release-lock digest');
  const acceptanceDigest = requireSha256(acceptanceSha256, 'Prompt-free acceptance digest');
  const verificationDigest = requireSha256(
    verificationSha256,
    'Private-release verification digest'
  );
  const attestationDigest = requireSha256(
    attestationSha256,
    'Prompt-free approval-attestation digest'
  );

  if (
    compatibility.schema_version !== 1 ||
    compatibility.scope !== 'private-personal-release' ||
    compatibility.transfer?.channel !== 'authenticated-github-draft-only' ||
    compatibility.transfer?.draft_required !== true ||
    compatibility.transfer?.public_download !== false ||
    compatibility.transfer?.owned_devices_only !== true ||
    compatibility.claims?.unofficial_wrapper !== true ||
    compatibility.claims?.dbcode_included !== false ||
    compatibility.claims?.licence_or_profile_included !== false ||
    compatibility.claims?.public_application_release !== false ||
    compatibility.claims?.apple_identified_or_notarized !== false
  ) {
    fail('Private-release compatibility policy is invalid.');
  }

  const releaseSetId = requireString(
    compatibility.release?.release_set_id,
    'Private-release release-set ID'
  );
  const sourceSetId = requireString(
    compatibility.release?.source_set_id,
    'Private-release source-set ID'
  );
  const sourceCommit = requireCommit(
    compatibility.source?.repository_revision,
    'Private-release source revision'
  );
  const sourceTag = requireString(compatibility.source?.tag, 'Private-release source tag');
  const appSha = requireSha256(compatibility.app?.sha256, 'Private-release app digest');
  const diskImageFilename = requireString(
    compatibility.disk_image?.filename,
    'Private-release disk-image filename'
  );
  const diskImageSha = requireSha256(
    compatibility.disk_image?.sha256,
    'Private-release disk-image digest'
  );
  requirePositiveInteger(
    compatibility.disk_image?.size_bytes,
    'Private-release disk-image size'
  );
  if (compatibility.disk_image?.read_only !== true) {
    fail('Private-release disk-image record is invalid.');
  }
  const profileSchemaVersion = requirePositiveInteger(
    releaseLock.release?.profile_schema_version,
    'Candidate profile schema'
  );
  if (
    releaseLock.release?.compatibility_status !== 'candidate' ||
    releaseLock.release?.validation_issue !== manifest.release?.validation_issue ||
    manifest.schema_version < 6 ||
    manifest.release?.release_set_id !== releaseSetId ||
    manifest.release?.source_set_id !== sourceSetId ||
    manifest.source?.repository_revision !== sourceCommit ||
    manifest.source?.snapshot?.repository_revision !== sourceCommit ||
    manifest.source?.snapshot?.tree_oid !== compatibility.source?.tree_oid ||
    manifest.source?.snapshot?.snapshot_sha256 !== compatibility.source?.snapshot_sha256 ||
    manifest.source?.compiled_host?.input_id !== compatibility.source?.compiled_host_input_id ||
    manifest.source?.release_lock_sha256 !== lockDigest ||
    manifest.artifact?.sha256 !== appSha ||
    manifest.artifact?.architecture !== compatibility.release?.architecture ||
    manifest.source?.code_oss?.tag !== compatibility.release?.code_oss_version ||
    manifest.source?.vscodium?.tag !== compatibility.release?.vscodium_version ||
    manifest.packaging?.status !== 'built-and-signed' ||
    compatibility.source?.release_lock_sha256 !== lockDigest ||
    compatibility.evidence?.build_manifest_sha256 !== manifestDigest ||
    compatibility.evidence?.release_lock_sha256 !== lockDigest ||
    compatibility.evidence?.final_acceptance_sha256 !== acceptanceDigest ||
    compatibility.evidence?.final_acceptance_status !== 'passed'
  ) {
    fail('Prompt-free approval inputs do not describe one exact candidate release set.');
  }
  requireCommit(manifest.source?.vscodium?.commit, 'Candidate VSCodium revision');
  requireCommit(manifest.source?.code_oss?.commit, 'Candidate Code OSS revision');
  requireCommit(manifest.source?.snapshot?.tree_oid, 'Candidate source tree');
  requireSha256(manifest.source?.snapshot?.snapshot_sha256, 'Candidate source-snapshot digest');
  requireSha256(manifest.source?.shell_patch_revision, 'Candidate shell-patch digest');
  requireSha256(manifest.source?.overlay_sha256, 'Candidate overlay digest');
  requirePattern(
    manifest.source?.compiled_host?.input_id,
    COMPILED_HOST_INPUT_PATTERN,
    'Candidate compiled-host input ID'
  );
  if (
    manifest.source?.snapshot?.schema_version !== 1 ||
    manifest.source?.snapshot?.mode !== 'immutable-git-commit' ||
    manifest.source?.snapshot?.host_script_sha256 !== manifest.source?.overlay_sha256 ||
    manifest.source?.snapshot?.release_lock_sha256 !== lockDigest ||
    manifest.source?.compiled_host?.schema_version !== 2 ||
    manifest.source?.compiled_host?.app_digest_algorithm !== 'sha256-files-modes-links-v1'
  ) {
    fail('Candidate immutable source snapshot is invalid.');
  }

  if (
    acceptance.schema_version !== 3 ||
    acceptance.status !== 'passed' ||
    acceptance.release?.release_set_id !== releaseSetId ||
    acceptance.release?.app_sha256 !== appSha ||
    acceptance.source?.repository_revision !== sourceCommit ||
    acceptance.source?.tree_oid !== compatibility.source?.tree_oid ||
    acceptance.source?.snapshot_sha256 !== compatibility.source?.snapshot_sha256 ||
    acceptance.source?.compiled_host_input_id !== compatibility.source?.compiled_host_input_id ||
    !Array.isArray(acceptance.failures) ||
    acceptance.failures.length !== 0 ||
    !Array.isArray(acceptance.waivers) ||
    acceptance.waivers.length !== 0
  ) {
    fail('Prompt-free acceptance does not approve this exact release set.');
  }

  const verificationChecks = Object.keys(verification.checks ?? {}).sort();
  if (
    verification.schema_version !== 1 ||
    verification.status !== 'passed' ||
    verification.release_set_id !== releaseSetId ||
    verification.source?.tag !== sourceTag ||
    verification.source?.repository_revision !== sourceCommit ||
    verification.source?.tree_oid !== compatibility.source?.tree_oid ||
    verification.source?.snapshot_sha256 !== compatibility.source?.snapshot_sha256 ||
    verification.source?.compiled_host_input_id !== compatibility.source?.compiled_host_input_id ||
    verification.disk_image?.filename !== diskImageFilename ||
    verification.disk_image?.sha256 !== diskImageSha ||
    verification.evidence?.build_manifest_sha256 !== manifestDigest ||
    verification.evidence?.release_lock_sha256 !== lockDigest ||
    verification.evidence?.final_acceptance_sha256 !== acceptanceDigest ||
    verification.evidence?.compatibility_manifest_sha256 !== compatibilityDigest ||
    verificationChecks.length !== PROMPT_FREE_VERIFICATION_CHECKS.length ||
    verificationChecks.some((name, index) => name !== PROMPT_FREE_VERIFICATION_CHECKS[index]) ||
    verificationChecks.some(name => verification.checks[name] !== 'passed') ||
    !Array.isArray(verification.failures) ||
    verification.failures.length !== 0
  ) {
    fail('Private-release verification does not approve this exact release set.');
  }
  requireSha256(
    verification.evidence?.checksum_sha256,
    'Private-release checksum-record digest'
  );
  requireSha256(
    verification.evidence?.install_and_rollback_sha256,
    'Private-release install-guide digest'
  );

  if (
    attestation.schema_version !== 2 ||
    attestation.release_set_id !== releaseSetId ||
    attestation.source_tag !== sourceTag ||
    attestation.compatibility_manifest_sha256 !== compatibilityDigest ||
    attestation.candidate_manifest_sha256 !== manifestDigest ||
    attestation.release_lock_sha256 !== lockDigest ||
    attestation.acceptance_sha256 !== acceptanceDigest ||
    attestation.verification_sha256 !== verificationDigest ||
    attestation.confirmation !== 'exact-release-set-id' ||
    attestation.approval_mode !== 'prompt-free-private-release' ||
    attestation.automatic_install !== false ||
    attestation.privileged_install !== false ||
    attestation.production_profile_written !== false ||
    attestation.installed_app_changed !== false
  ) {
    fail('Prompt-free approval attestation does not bind the exact candidate evidence.');
  }
  requireTimestamp(attestation.approved_at, 'Prompt-free approval timestamp');

  const dbcodePackages = Array.isArray(compatibility.external_runtime?.packages)
    ? compatibility.external_runtime.packages.filter(entry => entry.id === 'dbcode.dbcode')
    : [];
  const dbcode = dbcodePackages[0];
  if (
    compatibility.external_runtime?.bundled !== false ||
    compatibility.external_runtime?.setup !== 'focused-pinned-official-sources' ||
    compatibility.external_runtime?.source !== 'official-open-vsx' ||
    dbcodePackages.length !== 1 ||
    compatibility.release?.dbcode_version !== dbcode?.version
  ) {
    fail('Private-release external runtime policy is invalid.');
  }
  const record = {
    schema_version: 2,
    id: releaseSetId,
    source_set_id: sourceSetId,
    compatibility_status: 'approved',
    source_commit: sourceCommit,
    target: {
      platform: 'darwin',
      architecture: compatibility.release.architecture
    },
    profile: { schema_version: profileSchemaVersion },
    manifest: {
      schema_version: manifest.schema_version,
      build_manifest_sha256: manifestDigest,
      candidate_manifest_sha256: manifestDigest,
      approval_attestation_sha256: attestationDigest,
      artifact_sha256: appSha,
      shell_patch_revision: manifest.source.shell_patch_revision,
      overlay_sha256: manifest.source.overlay_sha256,
      source_snapshot_sha256: manifest.source.snapshot.snapshot_sha256,
      compiled_host_input_id: manifest.source.compiled_host.input_id,
      packaging_status: manifest.packaging.status
    },
    host: {
      vscodium_tag: requireVersion(
        manifest.source.vscodium?.tag,
        'Candidate VSCodium version'
      ),
      vscodium_commit: manifest.source.vscodium.commit,
      code_oss_tag: requireVersion(
        manifest.source.code_oss?.tag,
        'Candidate Code OSS version'
      ),
      code_oss_commit: manifest.source.code_oss.commit
    },
    dbcode: {
      id: dbcode.id,
      version: requireVersion(dbcode.version, 'Candidate DBCode version'),
      vsix_sha256: requireSha256(dbcode.vsix_sha256, 'Candidate DBCode package digest'),
      signature_archive_sha256: requireSha256(
        dbcode.signature_archive_sha256,
        'Candidate DBCode signature digest'
      )
    },
    approval: {
      approved_at: attestation.approved_at,
      validation_issue: requireString(
        manifest.release?.validation_issue,
        'Candidate validation issue'
      ),
      proof_sha256: acceptanceDigest,
      gate_receipt_sha256: verificationDigest,
      mode: 'prompt-free-private-release',
      source_tag: sourceTag,
      compatibility_manifest_sha256: compatibilityDigest,
      release_lock_sha256: lockDigest,
      production_profile_written: false,
      installed_app_changed: false
    }
  };
  validateApprovedRecord(record, { allowLegacy: false });
  return record;
}

function createApprovedRecord({
  candidateSet,
  manifest,
  attestation,
  candidateSetSha256,
  manifestSha256,
  attestationSha256,
  proofSha256,
  gateReceiptSha256
}) {
  validatePreparedReleaseSet(candidateSet);
  if (candidateSet.role !== 'candidate') {
    fail('Only a candidate prepared release set can be approved.');
  }
  requireObject(manifest, 'Candidate build manifest');
  requireObject(attestation, 'Approval attestation');
  const candidateDigest = requireSha256(candidateSetSha256, 'Candidate release-set digest');
  const manifestDigest = requireSha256(manifestSha256, 'Candidate build-manifest digest');
  const attestationDigest = requireSha256(attestationSha256, 'Approval attestation digest');
  const proofDigest = requireSha256(proofSha256, 'Candidate proof digest');
  const gateDigest = requireSha256(gateReceiptSha256, 'Compatibility gate digest');
  if (manifest.schema_version < 6 || manifest.release?.release_set_id !== candidateSet.release.release_set_id ||
      manifest.release?.source_set_id !== candidateSet.release.source_set_id) {
    fail('Candidate build manifest belongs to another release set.');
  }
  if (manifest.source?.repository_revision !== candidateSet.source.repository_revision ||
      manifest.source?.snapshot?.repository_revision !== candidateSet.source.repository_revision ||
      manifest.artifact?.sha256 !== candidateSet.host.app_sha256 ||
      manifest.source?.code_oss?.tag !== candidateSet.host.code_oss_version) {
    fail('Candidate build manifest does not match the prepared set.');
  }
  requireCommit(manifest.source?.vscodium?.commit, 'Candidate VSCodium revision');
  requireCommit(manifest.source?.code_oss?.commit, 'Candidate Code OSS revision');
  requireCommit(manifest.source?.snapshot?.tree_oid, 'Candidate source tree');
  requireSha256(manifest.source?.snapshot?.snapshot_sha256, 'Candidate source-snapshot digest');
  if (
    manifest.source?.snapshot?.schema_version !== 1 ||
    manifest.source?.snapshot?.mode !== 'immutable-git-commit' ||
    manifest.source?.snapshot?.host_script_sha256 !== manifest.source?.overlay_sha256 ||
    manifest.source?.snapshot?.release_lock_sha256 !== manifest.source?.release_lock_sha256 ||
    manifest.source?.compiled_host?.schema_version !== 2 ||
    manifest.source?.compiled_host?.app_digest_algorithm !== 'sha256-files-modes-links-v1'
  ) {
    fail('Candidate immutable source snapshot is invalid.');
  }
  requirePattern(
    manifest.source?.compiled_host?.input_id,
    COMPILED_HOST_INPUT_PATTERN,
    'Candidate compiled-host input ID'
  );
  requireSha256(manifest.source?.shell_patch_revision, 'Candidate shell-patch digest');
  requireSha256(manifest.source?.overlay_sha256, 'Candidate overlay digest');
  if (manifest.packaging?.status !== 'built-and-signed') {
    fail('Candidate package is not built and signed.');
  }
  if (
    attestation.schema_version !== 1 ||
    attestation.release_set_id !== candidateSet.release.release_set_id ||
    attestation.candidate_set_sha256 !== candidateDigest ||
    attestation.candidate_manifest_sha256 !== manifestDigest ||
    attestation.proof_sha256 !== proofDigest ||
    attestation.gate_receipt_sha256 !== gateDigest ||
    attestation.confirmation !== 'exact-release-set-id' ||
    attestation.automatic_install !== false ||
    attestation.privileged_install !== false
  ) {
    fail('Approval attestation does not bind the exact candidate evidence.');
  }
  requireTimestamp(attestation.approved_at, 'Approval timestamp');
  if (candidateSet.host.build_manifest_sha256 !== manifestDigest ||
      candidateSet.evidence.proof_sha256 !== proofDigest) {
    fail('Prepared release-set evidence does not match the approval inputs.');
  }
  const record = {
    schema_version: 2,
    id: candidateSet.release.release_set_id,
    source_set_id: candidateSet.release.source_set_id,
    compatibility_status: 'approved',
    source_commit: manifest.source.repository_revision,
    target: candidateSet.target,
    profile: { schema_version: candidateSet.profile.schema_version },
    manifest: {
      schema_version: manifest.schema_version,
      build_manifest_sha256: manifestDigest,
      candidate_manifest_sha256: manifestDigest,
      approval_attestation_sha256: attestationDigest,
      artifact_sha256: candidateSet.host.app_sha256,
      shell_patch_revision: manifest.source.shell_patch_revision,
      overlay_sha256: manifest.source.overlay_sha256,
      source_snapshot_sha256: manifest.source.snapshot.snapshot_sha256,
      compiled_host_input_id: manifest.source.compiled_host.input_id,
      packaging_status: manifest.packaging.status
    },
    host: {
      vscodium_tag: requireVersion(manifest.source.vscodium?.tag, 'Candidate VSCodium version'),
      vscodium_commit: manifest.source.vscodium.commit,
      code_oss_tag: requireVersion(manifest.source.code_oss?.tag, 'Candidate Code OSS version'),
      code_oss_commit: manifest.source.code_oss.commit
    },
    dbcode: {
      id: candidateSet.dbcode.id,
      version: candidateSet.dbcode.version,
      vsix_sha256: candidateSet.dbcode.vsix_sha256,
      signature_archive_sha256: candidateSet.dbcode.signature_archive_sha256
    },
    approval: {
      approved_at: attestation.approved_at,
      validation_issue: requireString(manifest.release?.validation_issue, 'Candidate validation issue'),
      proof_sha256: proofDigest,
      gate_receipt_sha256: gateDigest
    }
  };
  validateApprovedRecord(record, { allowLegacy: false });
  return record;
}

function upsertApprovedHistory(history, record) {
  const existing = history ?? { schema_version: 2, approved_release_sets: [] };
  validateApprovedHistory(existing);
  validateApprovedRecord(record, { allowLegacy: false });
  const next = {
    schema_version: 2,
    approved_release_sets: [
      ...existing.approved_release_sets.filter(entry => entry.id !== record.id),
      record
    ]
  };
  validateApprovedHistory(next);
  return next;
}

module.exports = {
  GIT_COMMIT_PATTERN,
  SHA256_PATTERN,
  COMPILED_HOST_INPUT_PATTERN,
  createApprovedRecord,
  createPromptFreeApprovedRecord,
  findApprovedCandidate,
  hasCanonicalSourceSetId,
  readPlainJsonFile,
  resolvePreparedMember,
  upsertApprovedHistory,
  validateApprovedHistory,
  validateApprovedRecord,
  validateInstalledReleaseSet,
  validatePreparedReleaseSet,
  validateRelativeMemberPath
};
