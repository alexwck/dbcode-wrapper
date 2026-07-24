const path = require('node:path');

if (process.argv.length !== 4) {
	console.error('Usage: node check_vscode_engine.cjs <Code OSS version> <extension engine range>');
	process.exit(2);
}

const [hostVersion, engineRange] = process.argv.slice(2);
const semverModule = path.resolve(
	path.dirname(process.execPath),
	'../lib/node_modules/npm/node_modules/semver'
);

let semver;
try {
	semver = require(semverModule);
} catch (error) {
	console.error(`The pinned Node toolchain does not contain npm's semver library: ${error.message}`);
	process.exit(2);
}

if (!semver.valid(hostVersion) || !semver.validRange(engineRange, { includePrerelease: true })) {
	console.error(`Invalid Code OSS version or extension engine range: ${hostVersion} / ${engineRange}`);
	process.exit(2);
}

process.exit(semver.satisfies(hostVersion, engineRange, { includePrerelease: true }) ? 0 : 1);
