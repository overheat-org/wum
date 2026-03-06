import { afterEach, describe, it } from "node:test";
import assert from "node:assert";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import Manifest from "../manifest";
import { ManifestType } from "@wum/shared";

describe("Manifest.parse", () => {
	let tmpDir = "";

	afterEach(async () => {
		if (tmpDir) {
			await fs.rm(tmpDir, { recursive: true, force: true });
			tmpDir = "";
		}
	});

	it("parses routes/dependencies/events from module keys", async () => {
		tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "wum-runtime-manifest-"));
		const filePath = path.join(tmpDir, "manifest.js");

		await fs.writeFile(filePath, `
			export default {
				[${ManifestType.Routes}]: [{ endpoint: "/ping", method: "get" }],
				[${ManifestType.Dependencies}]: [{ entity: class A {}, dependencies: [] }],
				[${ManifestType.Events}]: [{ type: "ready", handler: "OnReady" }]
			}
		`, "utf8");

		const manifest = await Manifest.parse(filePath);
		assert.deepEqual(manifest.routes, [{ endpoint: "/ping", method: "get" }]);
		assert.equal(Array.isArray(manifest.dependencies), true);
		assert.deepEqual(manifest.events, [{ type: "ready", handler: "OnReady" }]);
	});
});
