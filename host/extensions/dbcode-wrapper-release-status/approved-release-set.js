'use strict';

const fs = require('node:fs');
const { isDeepStrictEqual } = require('node:util');

const GIT_COMMIT_PATTERN = /^[0-9a-f]{40}$/;
const SHA1_PATTERN = /^[0-9a-fA-F]{40}$/;
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

function requireSha1(value, label) {
  return requirePattern(value, SHA1_PATTERN, label);
}

function requireHttpsUrl(value, label) {
  const text = requireString(value, label);
  if (!text.startsWith('https://')) {
    fail(`${label} is invalid.`);
  }
  return text;
}

function requireTarget(target, label = 'Release target') {
  requireObject(target, label);
  if (target.platform !== 'darwin' || target.architecture !== 'arm64') {
    fail(`${label} is unsupported.`);
  }
  return target;
}

function requireEvidenceArtifact(input, label) {
  requireObject(input, label);
  return {
    value: requireObject(input.value, `${label} document`),
    digest: requireSha256(input.digest, `${label} digest`)
  };
}

function sortByIdentity(records) {
  return [...records].sort((left, right) => {
    const leftKey = `${left.id ?? ''}@${left.version ?? ''}`;
    const rightKey = `${right.id ?? ''}@${right.version ?? ''}`;
    return leftKey < rightKey ? -1 : leftKey > rightKey ? 1 : 0;
  });
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
    if (!['prompt-free-private-release', 'prompt-free-public-host-release'].includes(
      record.approval.mode
    )) {
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

function validateReleaseSpecificationRecords(input) {
  requireObject(input, 'Validated Release Specification records');
  const build = requireObject(input.build, 'Release Specification build record');
  const extensions = requireObject(
    input.extensions,
    'Release Specification extension record'
  );
  const profile = requireObject(input.profile, 'Release Specification profile record');
  if (
    build.schema_version !== 1 ||
    extensions.schema_version !== 1 ||
    profile.schema_version !== 1 ||
    !isDeepStrictEqual(build.target, profile.target) ||
    !isDeepStrictEqual(build.product, profile.product) ||
    extensions.host_code_oss_version !== build.runtime?.code_oss_version
  ) {
    fail('Validated Release Specification records do not describe one release.');
  }
  requireTarget(build.target, 'Release Specification target');
  requirePositiveInteger(
    profile.profile_schema_version,
    'Release Specification profile schema'
  );
  if (!Array.isArray(extensions.packages) || extensions.packages.length === 0) {
    fail('Release Specification runtime package set is missing.');
  }
  return { build, extensions, profile };
}

function runtimeExtensionRecord(packageRecord) {
  return {
    role: packageRecord.role,
    id: packageRecord.id,
    version: packageRecord.version,
    target_platform: packageRecord.target_platform,
    verified_publisher: packageRecord.verified_publisher,
    vsix_sha256: packageRecord.sha256,
    signature_archive_sha256: packageRecord.signature_archive_sha256,
    public_key_id: packageRecord.public_key_id,
    public_key_sha256: packageRecord.public_key_sha256,
    install_location: 'external-private-profile',
    required: true
  };
}

function externalRuntimeRecord(packageRecord) {
  return {
    id: packageRecord.id,
    version: packageRecord.version,
    target_platform: packageRecord.target_platform,
    vsix_sha256: packageRecord.sha256,
    signature_archive_sha256: packageRecord.signature_archive_sha256,
    public_key_id: packageRecord.public_key_id,
    public_key_sha256: packageRecord.public_key_sha256
  };
}

function validateManifestAgainstReleaseSpecification(
  manifest,
  compatibility,
  releaseSpecification
) {
  const { build, extensions } = releaseSpecification;
  const codeOss = build.upstream.code_oss;
  const dbcode = extensions.dbcode;
  const packages = extensions.packages;
  const product = build.product;
  const release = build.release;
  const runtime = build.runtime;
  const vscodium = build.upstream.vscodium;
  const expectedManifestExtensions = sortByIdentity(
    packages.map(runtimeExtensionRecord)
  );
  const actualManifestExtensions = Array.isArray(manifest.runtime_extensions)
    ? sortByIdentity(manifest.runtime_extensions)
    : [];
  const expectedExternalRuntime = sortByIdentity(
    packages.map(externalRuntimeRecord)
  );
  const actualExternalRuntime = Array.isArray(
    compatibility.external_runtime?.packages
  )
    ? sortByIdentity(compatibility.external_runtime.packages)
    : [];

  if (
    manifest.release?.compatibility_status !== release.compatibility_status ||
    manifest.release?.wrapper_version !== release.wrapper_version ||
    manifest.release?.validation_issue !== release.validation_issue ||
    manifest.source?.vscodium?.tag !== vscodium.tag ||
    manifest.source?.vscodium?.commit !== vscodium.commit ||
    manifest.source?.code_oss?.tag !== codeOss.tag ||
    manifest.source?.code_oss?.commit !== codeOss.commit ||
    manifest.runtime?.code_oss !== runtime.code_oss_version ||
    manifest.runtime?.host !== vscodium.tag ||
    manifest.runtime?.electron !== runtime.electron_version ||
    manifest.artifact?.app_name !== product.app_name ||
    manifest.artifact?.application_name !== product.application_name ||
    manifest.artifact?.bundle_identifier !== product.bundle_identifier ||
    manifest.artifact?.platform !== 'darwin' ||
    manifest.artifact?.architecture !== 'arm64' ||
    manifest.artifact?.signature_kind !== 'certificate' ||
    manifest.artifact?.signature_scope !== 'current-user-private-use' ||
    manifest.artifact?.signing_certificate_common_name !==
      product.signing.identity_common_name ||
    compatibility.release?.code_oss_version !== runtime.code_oss_version ||
    compatibility.release?.vscodium_version !== vscodium.tag ||
    compatibility.release?.dbcode_version !== dbcode.version ||
    compatibility.release?.architecture !== 'arm64' ||
    compatibility.app?.filename !== `${product.app_name}.app` ||
    compatibility.app?.bundle_identifier !== product.bundle_identifier ||
    compatibility.app?.signature?.kind !==
      'current-user-self-signed-certificate' ||
    compatibility.app?.signature?.designated_requirement !==
      manifest.artifact?.signature_requirement ||
    compatibility.app?.signature?.developer_id !== false ||
    compatibility.app?.signature?.notarized !== false ||
    compatibility.external_runtime?.bundled !== false ||
    compatibility.external_runtime?.setup !==
      'focused-pinned-official-sources' ||
    compatibility.external_runtime?.source !== 'official-open-vsx' ||
    !isDeepStrictEqual(actualManifestExtensions, expectedManifestExtensions) ||
    !isDeepStrictEqual(actualExternalRuntime, expectedExternalRuntime)
  ) {
    fail('Candidate manifest or host-release metadata does not match the Release Specification.');
  }
  requireVersion(
    compatibility.release?.minimum_macos,
    'Host-release minimum macOS version'
  );
  requireString(
    manifest.artifact?.signature_requirement,
    'Candidate designated requirement'
  );
  requireSha1(
    manifest.artifact?.signing_certificate_sha1,
    'Candidate signing certificate SHA-1'
  );
  requireSha256(
    manifest.artifact?.signing_certificate_sha256,
    'Candidate signing certificate SHA-256'
  );
  requirePositiveInteger(
    manifest.packaging?.installed_kib,
    'Candidate installed size'
  );
}

function validatePromptFreeAcceptanceRecord({
  record,
  acceptanceDigest,
  manifestDigest,
  lockDigest,
  releaseSetId
}) {
  requireObject(record, 'Validated prompt-free acceptance record');
  if (
    record.schema_version !== 1 ||
    record.status !== 'validated' ||
    record.acceptance_schema_version !== 3 ||
    record.acceptance_sha256 !== acceptanceDigest ||
    record.build_manifest_sha256 !== manifestDigest ||
    record.release_lock_sha256 !== lockDigest ||
    record.release_set_id !== releaseSetId
  ) {
    fail('Validated prompt-free acceptance record belongs to another release set.');
  }
}

function promptFreeVerificationChecks() {
  return [...PROMPT_FREE_VERIFICATION_CHECKS];
}

function createPromptFreeApprovedRecord(input) {
  requireObject(input, 'Prompt-free approval input');
  const compatibilityInput = requireEvidenceArtifact(
    input.compatibility,
    'Host-release compatibility manifest'
  );
  const manifestInput = requireEvidenceArtifact(
    input.manifest,
    'Candidate build manifest'
  );
  const releaseLockInput = requireEvidenceArtifact(
    input.releaseLock,
    'Candidate Release Specification'
  );
  const acceptanceInput = requireEvidenceArtifact(
    input.acceptance,
    'Prompt-free acceptance report'
  );
  const verificationInput = requireEvidenceArtifact(
    input.verification,
    'Host-release verification receipt'
  );
  const attestationInput = requireEvidenceArtifact(
    input.attestation,
    'Prompt-free approval attestation'
  );
  const compatibility = compatibilityInput.value;
  const manifest = manifestInput.value;
  const verification = verificationInput.value;
  const attestation = attestationInput.value;
  const releaseSpecification = validateReleaseSpecificationRecords(
    input.releaseSpecification
  );
  const acceptanceValidation = input.acceptanceValidation;
  const compatibilityDigest = compatibilityInput.digest;
  const manifestDigest = manifestInput.digest;
  const lockDigest = releaseLockInput.digest;
  const acceptanceDigest = acceptanceInput.digest;
  const verificationDigest = verificationInput.digest;
  const attestationDigest = attestationInput.digest;

  if (
    compatibility.schema_version !== 1 ||
    compatibility.scope !== 'public-host-release' ||
    compatibility.transfer?.channel !== 'github-published-release' ||
    compatibility.transfer?.draft_required !== false ||
    compatibility.transfer?.public_download !== true ||
    compatibility.transfer?.owned_devices_only !== false ||
    compatibility.claims?.unofficial_wrapper !== true ||
    compatibility.claims?.dbcode_included !== false ||
    compatibility.claims?.licence_or_profile_included !== false ||
    compatibility.claims?.public_application_release !== true ||
    compatibility.claims?.apple_identified_or_notarized !== false
  ) {
    fail('Host-release compatibility policy is invalid.');
  }

  const releaseSetId = requireString(
    compatibility.release?.release_set_id,
    'Host-release release-set ID'
  );
  const sourceSetId = requireString(
    compatibility.release?.source_set_id,
    'Host-release source-set ID'
  );
  const wrapperVersion = requireVersion(
    compatibility.release?.wrapper_version,
    'Host-release wrapper version'
  );
  const sourceCommit = requireCommit(
    compatibility.source?.repository_revision,
    'Host-release source revision'
  );
  const sourceTag = requireString(compatibility.source?.tag, 'Host-release source tag');
  const appSha = requireSha256(compatibility.app?.sha256, 'Host-release app digest');
  const diskImageFilename = requireString(
    compatibility.disk_image?.filename,
    'Host-release disk-image filename'
  );
  const diskImageSha = requireSha256(
    compatibility.disk_image?.sha256,
    'Host-release disk-image digest'
  );
  requirePositiveInteger(
    compatibility.disk_image?.size_bytes,
    'Host-release disk-image size'
  );
  if (compatibility.disk_image?.read_only !== true) {
    fail('Host-release disk-image record is invalid.');
  }
  const profileSchemaVersion =
    releaseSpecification.profile.profile_schema_version;
  if (
    releaseSpecification.build.release?.compatibility_status !== 'candidate' ||
    releaseSpecification.build.release?.wrapper_version !== wrapperVersion ||
    sourceTag !== `v${wrapperVersion}` ||
    releaseSpecification.build.release?.validation_issue !==
      manifest.release?.validation_issue ||
    manifest.schema_version < 6 ||
    manifest.release?.wrapper_version !== wrapperVersion ||
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
  validateManifestAgainstReleaseSpecification(
    manifest,
    compatibility,
    releaseSpecification
  );
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

  validatePromptFreeAcceptanceRecord({
    record: acceptanceValidation,
    acceptanceDigest,
    manifestDigest,
    lockDigest,
    releaseSetId,
  });

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
    fail('Host-release verification does not approve this exact release set.');
  }
  requireSha256(
    verification.evidence?.checksum_sha256,
    'Host-release checksum-record digest'
  );
  requireSha256(
    verification.evidence?.install_and_rollback_sha256,
    'Host-release install-guide digest'
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
    attestation.approval_mode !== 'prompt-free-public-host-release' ||
    attestation.automatic_install !== false ||
    attestation.privileged_install !== false ||
    attestation.production_profile_written !== false ||
    attestation.installed_app_changed !== false
  ) {
    fail('Prompt-free approval attestation does not bind the exact candidate evidence.');
  }
  requireTimestamp(attestation.approved_at, 'Prompt-free approval timestamp');

  const dbcode = releaseSpecification.extensions.dbcode;
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
      vsix_sha256: requireSha256(dbcode.sha256, 'Candidate DBCode package digest'),
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
      mode: 'prompt-free-public-host-release',
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
  createPromptFreeApprovedRecord,
  findApprovedCandidate,
  promptFreeVerificationChecks,
  readPlainJsonFile,
  upsertApprovedHistory,
  validateApprovedHistory,
  validateApprovedRecord,
  validateInstalledReleaseSet
};
