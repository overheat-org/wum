import { afterEach, describe, it, mock } from "node:test";
import assert from "node:assert";
import Manifest from "../manifest";
import { Runtime } from "../runtime";
import EventManager from "../event";
import CommandManager from "../command";
import DependencyManager from "../di/manager";
import ProtocolsManager from "../protocols";

describe("Runtime.start", () => {
	afterEach(() => {
		mock.restoreAll();
	});

	it("loads manifest and delegates setup/load to managers", async () => {
		const calls = [];
		mock.method(Manifest, "parse", async (manifestPath) => {
			calls.push(["manifest.parse", manifestPath]);
			return {
				routes: [{ endpoint: "/ping", method: "get", handler: "h", entity: class C {} }],
				dependencies: [{ entity: class D {}, dependencies: [] }],
				events: [{ type: "ready", once: true, handler: "OnReady", entity: class E {} }],
			};
		});
		mock.method(EventManager.prototype, "setup", () => {
			calls.push(["event.setup"]);
		});
		mock.method(DependencyManager.prototype, "load", async (deps) => {
			calls.push(["dependency.load", deps]);
		});
		mock.method(CommandManager.prototype, "load", async (commandsPath) => {
			calls.push(["command.load", commandsPath]);
		});
		mock.method(ProtocolsManager.prototype, "load", async (routes) => {
			calls.push(["protocols.load", routes]);
		});
		mock.method(EventManager.prototype, "load", async (events) => {
			calls.push(["event.load", events]);
		});

		const runtime = new Runtime(
			{ guilds: { cache: new Map() }, application: { commands: { set: async () => {} } }, on: () => {}, once: () => {} },
			"/runtime-entry"
		);
		await runtime.start();

		assert.equal(calls[0][0], "manifest.parse");
		assert.equal(calls[0][1], "/runtime-entry/manifest.js");
		assert.equal(calls[1][0], "event.setup");
		assert.equal(calls[2][0], "dependency.load");
		assert.equal(calls[3][0], "command.load");
		assert.equal(calls[3][1], "/runtime-entry");
		assert.equal(calls.some(c => c[0] === "protocols.load"), true);
		assert.equal(calls.some(c => c[0] === "event.load"), true);
	});

	it("waits dependency resolution before loading protocols/events", async () => {
		const calls = [];
		let resolveDependencyLoad;

		mock.method(Manifest, "parse", async () => ({
			routes: [{ endpoint: "/ping", method: "get", handler: "h", entity: class C {} }],
			dependencies: [{ entity: class D {}, dependencies: [] }],
			events: [{ type: "ready", once: true, handler: "OnReady", entity: class E {} }],
		}));
		mock.method(EventManager.prototype, "setup", () => {});
		mock.method(DependencyManager.prototype, "load", () => {
			calls.push("dependency.load.start");
			return new Promise((resolve) => {
				resolveDependencyLoad = resolve;
			});
		});
		mock.method(CommandManager.prototype, "load", async () => {
			calls.push("command.load");
		});
		mock.method(ProtocolsManager.prototype, "load", async () => {
			calls.push("protocols.load");
		});
		mock.method(EventManager.prototype, "load", async () => {
			calls.push("event.load");
		});

		const runtime = new Runtime(
			{ guilds: { cache: new Map() }, application: { commands: { set: async () => {} } }, on: () => {}, once: () => {} },
			"/runtime-entry"
		);
		const startPromise = runtime.start();

		await Promise.resolve();
		assert.deepEqual(calls, ["dependency.load.start"]);

		resolveDependencyLoad();
		await startPromise;
		assert.equal(calls.includes("protocols.load"), true);
		assert.equal(calls.includes("event.load"), true);
	});
});
