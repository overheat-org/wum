import { describe, it } from "node:test";
import assert from "node:assert";
import { Events } from "discord.js";
import EventManager from "../event";

describe("EventManager", () => {
	it("loads and binds event handlers from dependency instances", async () => {
		const registrations = [];
		const instance = {
			calls: 0,
			OnReady() {
				this.calls += 1;
			},
		};
		const client = {
			on: (type, handler) => registrations.push({ kind: "on", type, handler }),
			once: (type, handler) => registrations.push({ kind: "once", type, handler }),
		};
		const dependencyManager = { getInstanceFrom: () => instance };
		const commandManager = { run: () => {}, register: async () => {} };
		const manager = new EventManager(client, dependencyManager, commandManager);

		await manager.load([{ type: "ready", once: true, handler: "OnReady", entity: class Init {} }]);
		assert.equal(registrations.length, 1);
		assert.equal(registrations[0].kind, "once");
		assert.equal(registrations[0].type, "ready");

		registrations[0].handler();
		assert.equal(instance.calls, 1);
	});

	it("wires interaction and ready hooks on setup", () => {
		const registrations = [];
		const client = {
			user: { tag: "bot#0001" },
			on: (type, handler) => registrations.push({ kind: "on", type, handler }),
			once: (type, handler) => registrations.push({ kind: "once", type, handler }),
		};
		const dependencyManager = { getInstanceFrom: () => ({}) };
		const commandManager = {
			runs: 0,
			registers: 0,
			run() { this.runs += 1; },
			register() { this.registers += 1; },
		};
		const manager = new EventManager(client, dependencyManager, commandManager);

		manager.setup();

		const interactionHook = registrations.find(r => r.kind === "on" && r.type === Events.InteractionCreate);
		const readyHook = registrations.find(r => r.kind === "once" && r.type === Events.ClientReady);
		assert.ok(interactionHook);
		assert.ok(readyHook);

		interactionHook.handler({ isChatInputCommand: () => true, isAutocomplete: () => false });
		assert.equal(commandManager.runs, 1);

		readyHook.handler();
		assert.equal(commandManager.registers, 1);
	});
});
