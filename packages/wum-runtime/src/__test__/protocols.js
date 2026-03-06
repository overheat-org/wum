import { afterEach, describe, it, mock } from "node:test";
import assert from "node:assert";
import ProtocolsManager from "../protocols";
import { HTTPManager } from "../protocols/http";

describe("ProtocolsManager", () => {
	afterEach(() => {
		mock.restoreAll();
	});

	it("binds route handlers to dependency instances", async () => {
		let capturedHandler;
		mock.method(HTTPManager.prototype, "get", (_path, handler) => {
			capturedHandler = handler;
		});

		const instance = {
			value: 41,
			ping() {
				return this.value + 1;
			},
		};
		const dependencyManager = { getInstanceFrom: () => instance };
		const manager = new ProtocolsManager(dependencyManager);

		await manager.load([
			{ endpoint: "/ping", method: "get", handler: "ping", entity: class PingController {} },
		]);

		assert.equal(typeof capturedHandler, "function");
		assert.equal(capturedHandler(), 42);
	});

	it("throws a clear error for unsupported route methods", async () => {
		const dependencyManager = { getInstanceFrom: () => ({ ping() {} }) };
		const manager = new ProtocolsManager(dependencyManager);

		await assert.rejects(() => manager.load([
			{ endpoint: "/ping", method: "trace", handler: "ping", entity: class PingController {} },
		]), /Unsupported protocol method/);
	});

	it("throws a clear error when a route handler is missing", async () => {
		const dependencyManager = { getInstanceFrom: () => ({}) };
		const manager = new ProtocolsManager(dependencyManager);

		await assert.rejects(() => manager.load([
			{ endpoint: "/ping", method: "get", handler: "ping", entity: class PingController {} },
		]), /Route handler 'ping' was not found/);
	});
});
