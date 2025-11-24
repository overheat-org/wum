import { FileTypes } from "@extn/shared";
import { Scanner } from "../src";
import { describe, it, mock } from 'node:test';
import fs from 'fs';

const cwd = "";
const commands = {
	'ping.tsx': `
		export default (
			<command name="ping">
				{() => "ping!"}
			</command>
		)
	`
}

const services = {
	'init.ts': `
		import Deinit from './deinit.ts';
	
		@service
		class Init {
			constructor(private deinit: Deinit) {}
		}
	`,
	'deinit.ts': `
		@injectable
		class Deinit {
			constructor() {}
		}
	`
}

describe("scan", () => {
	const scanner = new Scanner();

	let files = commands;
	
	mock.method(fs, 'glob', async function* () {
		for(const key of Object.keys(files)) {
			yield key;
		}
	});

	mock.method(fs, 'readFile', async (name, _) => {
		return files[name];
	});

	it("scan commands", () => {
		scanner.scanGlob("", { type: FileTypes.Command, cwd });
	});

	files = services;

	it("scan services", () => {
		scanner.scanGlob("", { type: FileTypes.Service, cwd });
	});
})

