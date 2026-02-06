export const Logger = {
	startup(version: string) {
		console.log(`   ☯ \x1b[1mWum\x1b[0mCord ${version}\n`);
	},

	ready(usertag: string) {
		console.log(`\x1b[32m● Ready as \x1b[1m${usertag}\x1b[0m\x1b[32m\x1b[0m`);
	},

	warn(text: string) {
		console.warn(`\x1b[33m⚠ Warning |\x1b[0m ${text}`);
	},

	error(text: string) {
		console.error(`Error | ${text}`);
	}
}
