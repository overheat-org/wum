import { describe, it } from "node:test";
import assert from "node:assert";
import { DependencyInjectorResolver } from "../di/resolver";

class FakeClient {}

describe("DependencyInjectorResolver", () => {
	it("parses service/managers dependency entries from manifest", async () => {
		class ServiceA {}
		class ManagerA {}
		class ManagerB {}
		const resolver = new DependencyInjectorResolver(new FakeClient());

		await resolver.parseGraph([
			{ service: ServiceA, dependencies: [] },
			{ name: "core", managers: [ManagerA, ManagerB] },
		]);
		await resolver.resolve();

		assert.ok(resolver.instanceFromDependency.get(ServiceA));
		assert.ok(resolver.instanceFromDependency.get(ManagerA));
		assert.ok(resolver.instanceFromDependency.get(ManagerB));
	});

	it("keeps instances separated for classes sharing the same name", async () => {
		const ServiceA = class Service {};
		const ServiceB = class Service {};
		const resolver = new DependencyInjectorResolver(new FakeClient());

		resolver.register(ServiceA, []);
		resolver.register(ServiceB, []);
		await resolver.resolve();

		assert.notEqual(resolver.instanceFromDependency.get(ServiceA), resolver.instanceFromDependency.get(ServiceB));
	});

	it("cleans processing stack after constructor failures", async () => {
		class Broken {
			constructor() {
				throw new Error("boom");
			}
		}

		const resolver = new DependencyInjectorResolver(new FakeClient());
		resolver.register(Broken, []);

		await assert.rejects(() => resolver.resolve(), /boom/);
		await assert.rejects(() => resolver.resolve(), /boom/);
	});
});
