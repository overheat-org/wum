import { afterEach, describe, it } from "node:test";
import assert from "node:assert";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import CommandManager from "../command";

describe("CommandManager", () => {
	let tmpDir = "";

	afterEach(async () => {
		delete process.env.GUILD_ID;
		if (tmpDir) {
			await fs.rm(tmpDir, { recursive: true, force: true });
			tmpDir = "";
		}
	});

	it("loads container from commands.js", async () => {
		tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "wum-runtime-command-"));
		await fs.writeFile(
			path.join(tmpDir, "commands.js"),
			"export default { list: [{ name: 'ping' }] };",
			"utf8"
		);

		const manager = new CommandManager({ guilds: { cache: new Map() }, application: { commands: { set: async () => {} } } });
		await manager.load(tmpDir);

		assert.ok(manager["container"]);
		assert.deepEqual(manager["container"].list, [{ name: "ping" }]);
	});

	it("loads container when a file path is provided", async () => {
		tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "wum-runtime-command-file-"));
		const filePath = path.join(tmpDir, "commands.js");
		await fs.writeFile(
			filePath,
			"export default { list: [{ name: 'pong' }] };",
			"utf8"
		);

		const manager = new CommandManager({ guilds: { cache: new Map() }, application: { commands: { set: async () => {} } } });
		await manager.load(filePath);

		assert.ok(manager["container"]);
		assert.deepEqual(manager["container"].list, [{ name: "pong" }]);
	});

	it("registers in guild commands when GUILD_ID exists", async () => {
		process.env.GUILD_ID = "guild-1";
		const calls = [];
		const guild = { commands: { set: async (v) => calls.push(v) } };
		const client = {
			guilds: { cache: new Map([["guild-1", guild]]) },
			application: { commands: { set: async () => assert.fail("should not call application commands") } },
		};
		const manager = new CommandManager(client);
		manager["container"] = { list: [{ name: "pong" }] };

		await manager.register();
		assert.equal(calls.length, 1);
		assert.deepEqual(calls[0], [{ name: "pong" }]);
	});

	it("registers in application commands when guild is unavailable", async () => {
		const calls = [];
		const client = {
			guilds: { cache: new Map() },
			application: { commands: { set: async (v) => calls.push(v) } },
		};
		const manager = new CommandManager(client);
		manager["container"] = { list: [{ name: "help" }] };

		await manager.register();
		assert.equal(calls.length, 1);
		assert.deepEqual(calls[0], [{ name: "help" }]);
	});
});
