'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const profileLayout = require('../../host/extensions/dbcode-wrapper-profile-migration/profile-layout');

const CLASSIFICATIONS = Object.freeze([
  'active-evidence',
  'rollback-evidence',
  'final-transfer-assets',
  'reusable-cache',
  'rebuildable-work',
  'expired-output',
  'unknown'
]);
const CLASSIFICATION_SET = new Set(CLASSIFICATIONS);

function fail(message) {
  throw new Error(message);
}

function contains(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === '' || (
    relative !== '..' &&
    !relative.startsWith(`..${path.sep}`) &&
    !path.isAbsolute(relative)
  );
}

function checkedAbsolutePath(value, label) {
  if (typeof value !== 'string' || value.length === 0) {
    fail(`${label} is required.`);
  }
  const resolved = path.resolve(value);
  if (!path.isAbsolute(resolved) || resolved === path.parse(resolved).root) {
    fail(`${label} is too broad.`);
  }
  return resolved;
}

function checkedExistingDirectory(value, label) {
  const resolved = checkedAbsolutePath(value, label);
  let metadata;
  try {
    metadata = fs.lstatSync(resolved);
  } catch (error) {
    if (error?.code === 'ENOENT') {
      fail(`${label} does not exist: ${resolved}`);
    }
    throw error;
  }
  if (metadata.isSymbolicLink()) {
    fail(`${label} must not be a symbolic link: ${resolved}`);
  }
  if (!metadata.isDirectory()) {
    fail(`${label} must be a directory: ${resolved}`);
  }
  return resolved;
}

function assertNoSymbolicLink(basePath, candidatePath) {
  if (!contains(basePath, candidatePath)) {
    fail(`The generated path is outside its safety root: ${candidatePath}`);
  }
  const relative = path.relative(basePath, candidatePath);
  const components = relative === '' ? [] : relative.split(path.sep);
  let current = basePath;
  for (const component of ['', ...components]) {
    if (component !== '') {
      current = path.join(current, component);
    }
    let metadata;
    try {
      metadata = fs.lstatSync(current);
    } catch (error) {
      if (error?.code === 'ENOENT') {
        break;
      }
      throw error;
    }
    if (metadata.isSymbolicLink()) {
      fail(`The generated path contains a symbolic link: ${current}`);
    }
  }
}

function managedRoot(
  repoRoot,
  id,
  relativePath,
  classification,
  owner,
  reason,
  deletionAllowed,
  inspectSize = false,
  uninspectedSizeStatus = 'protected-artifact-not-inspected'
) {
  if (!CLASSIFICATION_SET.has(classification) || classification === 'unknown') {
    fail(`The generated root ${id} has an invalid maintained classification.`);
  }
  return {
    id,
    path: path.join(repoRoot, relativePath),
    classification,
    owner,
    reason,
    deletion_allowed: deletionAllowed,
    inspect_size: inspectSize,
    uninspected_size_status: uninspectedSizeStatus,
    scope: 'repository'
  };
}

function privateProfileRoot(id, profilePath, reason) {
  return {
    id,
    path: profilePath,
    classification: 'active-evidence',
    owner: 'standalone-profile',
    reason,
    deletion_allowed: false,
    inspect_size: false,
    uninspected_size_status: 'private-profile-not-inspected',
    scope: 'private-profile'
  };
}

function createRetentionContract({
  repoRoot,
  homeDirectory
}) {
  const checkedRepoRoot = checkedExistingDirectory(repoRoot, 'Repository root');
  const checkedHome = checkedExistingDirectory(homeDirectory, 'Current user home directory');
  const buildRoot = path.join(checkedRepoRoot, '.build');
  const currentProfile = profileLayout.createProfileLayout({
    profileName: 'default',
    homeDirectory: checkedHome,
    buildRoot
  });
  const roots = [
    managedRoot(
      checkedRepoRoot,
      'build-work',
      '.build/work',
      'rebuildable-work',
      'prepare-source',
      'Generated Code OSS and VSCodium worktrees stay retained until their owning workflow explicitly releases them.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'build-coordination',
      '.build/locks',
      'rebuildable-work',
      'host-build',
      'Short-lived build and release leases prevent concurrent commands from reading or replacing an incomplete Host checkpoint.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'assembly-work',
      '.build/assembly',
      'rebuildable-work',
      'host-build',
      'Staged Host checkpoints remain build-owned until one complete checkpoint replaces dist.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'generated-source',
      '.build/generated',
      'rebuildable-work',
      'source-generation',
      'Generated source snapshots stay retained until their owning workflow explicitly releases them.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'rollback-worktrees',
      '.build/rollback-worktrees',
      'rebuildable-work',
      'release-rollback',
      'Rollback worktrees remain owned by the rollback workflow until it explicitly releases them.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'download-cache',
      '.build/downloads',
      'reusable-cache',
      'release-downloads',
      'Downloaded public build inputs remain reusable cache until the release-download workflow explicitly expires them.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'build-cache',
      '.build/cache',
      'reusable-cache',
      'host-build',
      'Verified source, package, and Compiled Host caches remain reusable until the host-build workflow explicitly expires them.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'toolchain-cache',
      '.build/toolchains',
      'reusable-cache',
      'toolchain-bootstrap',
      'Pinned toolchains remain reusable until the toolchain workflow explicitly expires them.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'expired-output',
      '.build/expired',
      'expired-output',
      'generated-workspace-retention',
      'Only output deliberately moved under this root has been declared expired.',
      true,
      true
    ),
    managedRoot(
      checkedRepoRoot,
      'expired-catalogue-output',
      '.build/q',
      'expired-output',
      'focused-shell-rendered',
      'The old short-path connection-catalogue profile was replaced by the persistent generated QA profile.',
      true,
      true
    ),
    managedRoot(
      checkedRepoRoot,
      'smoke-evidence',
      '.build/smoke',
      'active-evidence',
      'host-smoke',
      'The latest static and runtime host smoke evidence remains active acceptance evidence.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'expired-smoke-output',
      '.build/smoke-backups',
      'expired-output',
      'host-smoke',
      'The abandoned smoke-backup root is not used by the maintained static smoke workflow.',
      true,
      true
    ),
    managedRoot(
      checkedRepoRoot,
      'finder-metadata',
      '.build/.DS_Store',
      'expired-output',
      'macos-finder',
      'Finder metadata is ignored and does not contain wrapper evidence or reusable build state.',
      true,
      true
    ),
    managedRoot(
      checkedRepoRoot,
      'retained-release-proof',
      '.build/proof',
      'active-evidence',
      'historical-release-evidence',
      'Historical release proof output remains protected until an explicit expiry record names it.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'rendered-evidence',
      '.build/qa',
      'active-evidence',
      'focused-shell-rendered',
      'The current rendered focused-shell profile and reports remain active acceptance evidence.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'rendered-screenshots',
      'output/playwright',
      'active-evidence',
      'focused-shell-rendered',
      'The current rendered screenshots remain active acceptance evidence.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'retained-release-comparison',
      '.build/controlled-upgrade',
      'active-evidence',
      'historical-release-evidence',
      'Historical release comparison and rollback output remains protected until an explicit expiry record names it.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'retained-release-transition',
      '.build/u',
      'active-evidence',
      'historical-release-evidence',
      'Historical short-path release evidence remains protected until an explicit expiry record names it.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'acceptance-evidence',
      '.build/acceptance',
      'active-evidence',
      'release-acceptance',
      'Current and retained prompt-free acceptance reports remain protected until explicitly expired.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'accepted-host',
      'dist',
      'active-evidence',
      'accepted-release-set',
      'The current signed app and build manifest remain protected until a newer accepted release explicitly replaces them.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'rollback-evidence',
      '.build/approved-release-backups',
      'rollback-evidence',
      'release-rollback',
      'Approved rollback backups remain protected until the rollback workflow explicitly records their expiry.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'retained-release-transfer',
      '.build/private-release',
      'final-transfer-assets',
      'historical-release-evidence',
      'Historical release-transfer assets remain protected until an explicit expiry record names them.',
      false
    ),
    managedRoot(
      checkedRepoRoot,
      'host-release-assets',
      '.build/host-release',
      'final-transfer-assets',
      'published-host-release',
      'Verified public host-release assets remain protected until the release workflow explicitly expires them.',
      false
    ),
    privateProfileRoot(
      'current-profile-state',
      currentProfile.paths.state,
      'The current private profile state, installed extensions, and licence continuity are never inspected or cleaned by this command.'
    ),
    privateProfileRoot(
      'current-profile-user-data',
      currentProfile.paths.user_data,
      'The current private user data and Safe Storage references are never inspected or cleaned by this command.'
    ),
    privateProfileRoot(
      'current-profile-shared-data',
      currentProfile.paths.shared_data,
      'The current private shared data is never inspected or cleaned by this command.'
    ),
    privateProfileRoot(
      'current-profile-backups',
      currentProfile.paths.backup,
      'Approved private profile backups are never inspected or cleaned by this command.'
    )
  ];

  return {
    schema_version: 1,
    repository_root: checkedRepoRoot,
    home_directory: checkedHome,
    roots
  };
}

function pathSize(pathValue) {
  let metadata;
  try {
    metadata = fs.lstatSync(pathValue);
  } catch (error) {
    if (error?.code === 'ENOENT') {
      return { exists: false, size_bytes: 0, size_status: 'missing' };
    }
    return {
      exists: null,
      size_bytes: null,
      size_status: `unavailable-${error?.code ?? 'error'}`
    };
  }
  if (metadata.isSymbolicLink()) {
    return {
      exists: true,
      size_bytes: metadata.size,
      size_status: 'symbolic-link-not-followed'
    };
  }
  if (!metadata.isDirectory()) {
    return { exists: true, size_bytes: metadata.size, size_status: 'measured' };
  }
  let sizeBytes = metadata.size;
  let containsSymbolicLink = false;
  try {
    for (const child of fs.readdirSync(pathValue)) {
      const childSize = pathSize(path.join(pathValue, child));
      if (childSize.size_bytes === null) {
        return {
          exists: true,
          size_bytes: null,
          size_status: childSize.size_status
        };
      }
      if (childSize.size_status.includes('symbolic-link')) {
        containsSymbolicLink = true;
      }
      sizeBytes += childSize.size_bytes;
    }
  } catch (error) {
    return {
      exists: true,
      size_bytes: null,
      size_status: `unavailable-${error?.code ?? 'error'}`
    };
  }
  return {
    exists: true,
    size_bytes: sizeBytes,
    size_status: containsSymbolicLink ? 'contains-symbolic-link' : 'measured'
  };
}

function describeRoot(root, repoRoot) {
  if (root.scope === 'private-profile') {
    return {
      ...root,
      exists: null,
      size_bytes: null,
      size_status: root.uninspected_size_status,
      deletion_allowed: false
    };
  }
  let safety = 'validated';
  try {
    assertNoSymbolicLink(repoRoot, root.path);
  } catch (error) {
    safety = error instanceof Error ? error.message : String(error);
  }
  let measured;
  if (safety !== 'validated') {
    measured = {
      exists: null,
      size_bytes: null,
      size_status: 'unsafe-symbolic-link'
    };
  } else if (root.inspect_size) {
    measured = pathSize(root.path);
  } else {
    try {
      fs.lstatSync(root.path);
      measured = {
        exists: true,
        size_bytes: null,
        size_status: root.uninspected_size_status
      };
    } catch (error) {
      measured = error?.code === 'ENOENT'
        ? { exists: false, size_bytes: 0, size_status: 'missing' }
        : {
            exists: null,
            size_bytes: null,
            size_status: `unavailable-${error?.code ?? 'error'}`
          };
    }
  }
  const measuredSafely = measured.exists === true && measured.size_status === 'measured';
  return {
    ...root,
    ...measured,
    deletion_allowed: root.deletion_allowed && safety === 'validated' && measuredSafely,
    safety
  };
}

function discoverUnknownEntries(contract) {
  const containers = [
    path.join(contract.repository_root, '.build'),
    path.join(contract.repository_root, 'output')
  ];
  const unknown = [];
  for (const container of containers) {
    let metadata;
    try {
      metadata = fs.lstatSync(container);
    } catch (error) {
      if (error?.code === 'ENOENT') {
        continue;
      }
      throw error;
    }
    if (!metadata.isDirectory() || metadata.isSymbolicLink()) {
      unknown.push({
        id: null,
        path: container,
        classification: 'unknown',
        owner: 'unregistered',
        reason: 'A generated workspace container is not a plain registered directory.',
        deletion_allowed: false,
        inspect_size: false,
        scope: 'repository',
        exists: true,
        size_bytes: null,
        size_status: 'unsafe-container'
      });
      continue;
    }
    for (const childName of fs.readdirSync(container).sort()) {
      const childPath = path.join(container, childName);
      const covered = contract.roots.some(root => (
        root.scope === 'repository' &&
        (contains(root.path, childPath) || contains(childPath, root.path))
      ));
      if (!covered) {
        unknown.push({
          id: null,
          path: childPath,
          classification: 'unknown',
          owner: 'unregistered',
          reason: 'This generated path is not registered in the maintained retention contract.',
          deletion_allowed: false,
          inspect_size: false,
          scope: 'repository',
          exists: true,
          size_bytes: null,
          size_status: 'unregistered-path-not-inspected'
        });
      }
    }
  }
  return unknown;
}

function inventoryGeneratedWorkspace(options) {
  const contract = createRetentionContract(options);
  const entries = [
    ...contract.roots.map(root => describeRoot(root, contract.repository_root)),
    ...discoverUnknownEntries(contract)
  ].sort((left, right) => left.path.localeCompare(right.path));
  return {
    schema_version: 1,
    command: 'inventory',
    generated_at: new Date().toISOString(),
    repository_root: contract.repository_root,
    mutation_performed: false,
    entries
  };
}

function resolveCandidatePath(repoRoot, candidatePath) {
  if (typeof candidatePath !== 'string' || candidatePath.length === 0) {
    fail('An exact generated path is required.');
  }
  return path.resolve(repoRoot, candidatePath);
}

function findOwningRoot(contract, candidatePath) {
  return contract.roots
    .filter(root => contains(root.path, candidatePath))
    .sort((left, right) => right.path.length - left.path.length)[0] ?? null;
}

function assertNotBroadSelection(contract, candidatePath) {
  const filesystemRoot = path.parse(candidatePath).root;
  if (candidatePath === filesystemRoot) {
    fail('Cleanup refuses the filesystem root.');
  }
  if (candidatePath === contract.repository_root) {
    fail('Cleanup refuses the repository root.');
  }
  if (candidatePath === contract.home_directory) {
    fail('Cleanup refuses the current user home directory.');
  }
}

function exactCleanupEntry(contract, candidatePath) {
  const resolved = resolveCandidatePath(contract.repository_root, candidatePath);
  assertNotBroadSelection(contract, resolved);
  const owner = findOwningRoot(contract, resolved);
  if (!owner) {
    fail(`Cleanup refuses an unknown generated path: ${resolved}`);
  }
  if (owner.scope !== 'repository') {
    fail(`Cleanup refuses active evidence in the current private profile: ${resolved}`);
  }
  if (!owner.deletion_allowed || !owner.inspect_size) {
    const label = owner.classification.replaceAll('-', ' ');
    fail(`Cleanup refuses ${label}: ${resolved}`);
  }
  assertNoSymbolicLink(contract.repository_root, resolved);
  const measured = pathSize(resolved);
  if (measured.exists !== true) {
    fail(`Cleanup requires an existing exact generated path: ${resolved}`);
  }
  if (measured.size_status !== 'measured') {
    fail(`Cleanup refuses a path that could not be fully validated: ${resolved}`);
  }
  return {
    id: owner.id,
    path: resolved,
    classification: owner.classification,
    owner: owner.owner,
    reason: owner.reason,
    deletion_allowed: true,
    ...measured
  };
}

function planCleanup({
  repoRoot,
  homeDirectory,
  selector
}) {
  const contract = createRetentionContract({
    repoRoot,
    homeDirectory
  });
  if (!selector || typeof selector !== 'object' || Array.isArray(selector)) {
    fail('Cleanup requires one explicit class or exact path.');
  }
  const selectorKeys = Object.keys(selector);
  if (selectorKeys.length !== 1 || !['classification', 'path'].includes(selectorKeys[0])) {
    fail('Cleanup accepts exactly one explicit class or exact path.');
  }

  let items;
  let selection;
  if (Object.hasOwn(selector, 'classification')) {
    const classification = selector.classification;
    if (!CLASSIFICATION_SET.has(classification) || classification === 'unknown') {
      fail(`Cleanup refuses an unknown classification: ${classification}`);
    }
    const selectedRoots = contract.roots.filter(root => root.classification === classification);
    if (selectedRoots.length === 0) {
      fail(`Cleanup found no maintained roots for classification: ${classification}`);
    }
    const protectedRoot = selectedRoots.find(root => !root.deletion_allowed);
    if (protectedRoot) {
      const label = protectedRoot.classification.replaceAll('-', ' ');
      fail(`Cleanup refuses ${label}: ${protectedRoot.path}`);
    }
    items = selectedRoots
      .map(root => describeRoot(root, contract.repository_root))
      .filter(root => root.exists === true);
    const unsafeItem = items.find(root => !root.deletion_allowed);
    if (unsafeItem) {
      if (unsafeItem.size_status.includes('symbolic-link')) {
        fail(`Cleanup refuses a path containing a symbolic link: ${unsafeItem.path}`);
      }
      fail(`Cleanup refuses a path that could not be fully validated: ${unsafeItem.path}`);
    }
    selection = { kind: 'classification', value: classification };
  } else {
    items = [exactCleanupEntry(contract, selector.path)];
    selection = { kind: 'exact-path', value: items[0].path };
  }

  return {
    schema_version: 1,
    command: 'cleanup',
    generated_at: new Date().toISOString(),
    repository_root: contract.repository_root,
    selection,
    dry_run: true,
    execution_supported: selection.kind === 'exact-path',
    mutation_performed: false,
    items
  };
}

function executeCleanup({
  repoRoot,
  homeDirectory,
  selector
}) {
  if (
    !selector ||
    typeof selector !== 'object' ||
    Array.isArray(selector) ||
    Object.keys(selector).length !== 1 ||
    !Object.hasOwn(selector, 'path')
  ) {
    fail('Cleanup apply requires one exact path.');
  }

  const plan = planCleanup({
    repoRoot,
    homeDirectory,
    selector
  });
  const contract = createRetentionContract({
    repoRoot,
    homeDirectory
  });
  const planned = plan.items[0];
  const validated = exactCleanupEntry(contract, planned.path);
  if (
    planned.path !== validated.path ||
    planned.size_bytes !== validated.size_bytes ||
    planned.size_status !== validated.size_status
  ) {
    fail(`Cleanup target changed during validation: ${planned.path}`);
  }

  const metadata = fs.lstatSync(validated.path);
  if (metadata.isSymbolicLink()) {
    fail(`Cleanup refuses a symbolic link: ${validated.path}`);
  }
  fs.rmSync(validated.path, {
    recursive: metadata.isDirectory(),
    force: false
  });
  try {
    fs.lstatSync(validated.path);
    fail(`Cleanup could not remove the exact generated path: ${validated.path}`);
  } catch (error) {
    if (error?.code !== 'ENOENT') {
      throw error;
    }
  }

  return {
    ...plan,
    dry_run: false,
    execution_supported: true,
    mutation_performed: true,
    items: [{
      ...validated,
      removed: true,
      exists_after: false
    }]
  };
}

function rootById(contract, id) {
  if (typeof id !== 'string' || id.length === 0) {
    fail('A generated workspace root ID is required.');
  }
  const root = contract.roots.find(candidate => candidate.id === id);
  if (!root) {
    fail(`Unknown generated workspace root ID: ${id}`);
  }
  return root;
}

function resolveManagedPath({
  repoRoot,
  homeDirectory,
  id
}) {
  const contract = createRetentionContract({
    repoRoot,
    homeDirectory
  });
  const managed = rootById(contract, id);
  if (managed.scope !== 'repository') {
    fail(`Workflow output cannot target the current private profile: ${managed.path}`);
  }
  assertNoSymbolicLink(contract.repository_root, managed.path);
  return managed.path;
}

function defaultTemporaryRoots() {
  const roots = [os.tmpdir(), '/tmp', '/private/tmp'];
  for (const candidate of [...roots]) {
    try {
      roots.push(fs.realpathSync(candidate));
    } catch (error) {
      if (error?.code !== 'ENOENT') {
        throw error;
      }
    }
  }
  return [...new Set(roots.map(candidate => path.resolve(candidate)))];
}

function checkedTemporaryRoot(value) {
  const lexicalPath = checkedAbsolutePath(value, 'Validated temporary root');
  let physicalPath;
  try {
    physicalPath = fs.realpathSync(lexicalPath);
  } catch (error) {
    if (error?.code === 'ENOENT') {
      fail(`Validated temporary root does not exist: ${lexicalPath}`);
    }
    throw error;
  }
  const metadata = fs.lstatSync(physicalPath);
  if (!metadata.isDirectory() || metadata.isSymbolicLink()) {
    fail(`Validated temporary root must resolve to a plain directory: ${lexicalPath}`);
  }
  return { lexicalPath, physicalPath };
}

function assertNoSymbolicLinkBelowRoot(rootPath, candidatePath) {
  if (!contains(rootPath, candidatePath)) {
    fail(`The generated path is outside its safety root: ${candidatePath}`);
  }
  const relative = path.relative(rootPath, candidatePath);
  const components = relative === '' ? [] : relative.split(path.sep);
  let current = rootPath;
  for (const component of components) {
    current = path.join(current, component);
    let metadata;
    try {
      metadata = fs.lstatSync(current);
    } catch (error) {
      if (error?.code === 'ENOENT') {
        break;
      }
      throw error;
    }
    if (metadata.isSymbolicLink()) {
      fail(`The generated path contains a symbolic link: ${current}`);
    }
  }
}

function assertManagedPath({
  repoRoot,
  homeDirectory,
  id,
  candidatePath,
  allowTemporary = false,
  temporaryRoots = defaultTemporaryRoots()
}) {
  const contract = createRetentionContract({
    repoRoot,
    homeDirectory
  });
  const managed = rootById(contract, id);
  const resolved = resolveCandidatePath(contract.repository_root, candidatePath);
  assertNotBroadSelection(contract, resolved);
  if (contains(managed.path, resolved)) {
    if (managed.scope !== 'repository') {
      fail(`Workflow output cannot target the current private profile: ${resolved}`);
    }
    assertNoSymbolicLink(contract.repository_root, resolved);
    return {
      schema_version: 1,
      id: managed.id,
      path: resolved,
      managed_root: managed.path,
      temporary_fixture: false,
      classification: managed.classification
    };
  }
  if (allowTemporary) {
    for (const temporaryRootValue of temporaryRoots) {
      const temporaryRoot = checkedTemporaryRoot(temporaryRootValue);
      if (resolved === temporaryRoot.lexicalPath) {
        fail(`Workflow output cannot be the temporary root itself: ${resolved}`);
      }
      if (contains(temporaryRoot.lexicalPath, resolved)) {
        assertNoSymbolicLinkBelowRoot(temporaryRoot.lexicalPath, resolved);
        const physicalPath = path.join(
          temporaryRoot.physicalPath,
          path.relative(temporaryRoot.lexicalPath, resolved)
        );
        return {
          schema_version: 1,
          id: managed.id,
          path: physicalPath,
          managed_root: managed.path,
          temporary_fixture: true,
          classification: managed.classification
        };
      }
    }
  }
  fail(`Workflow output is outside the ${id} managed root: ${resolved}`);
}

module.exports = {
  assertManagedPath,
  executeCleanup,
  inventoryGeneratedWorkspace,
  planCleanup,
  resolveManagedPath
};
