'use strict';

function isExpectedRuntimeExtensionShutdownChannelClose(lines, index) {
	const line = lines[index] ?? '';
	if (!/\[error\]\s+Error: Channel has been closed\s*$/.test(line)) {
		return false;
	}

	const before = lines.slice(Math.max(0, index - 3), index);
	const after = lines.slice(index + 1, index + 16);
	return before.some(candidate => candidate.includes('Extension host terminating: received terminate message from renderer'))
		&& after.some(candidate => candidate.includes('logOutputMessage')
			&& /(?:dbcode\.dbcode-[^/]+\/out\/extension\/extension\.js|ms-python\.python-[^/]+\/out\/client\/extension\.js)/.test(candidate))
		&& after.some(candidate => candidate.includes('ChildProcess.<anonymous>'))
		&& after.some(candidate => /Extension host with pid \d+ exiting with code 0/.test(candidate));
}

module.exports = {
	isExpectedRuntimeExtensionShutdownChannelClose
};
