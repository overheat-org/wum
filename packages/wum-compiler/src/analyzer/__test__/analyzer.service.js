import { describe, it } from 'node:test';
import assert from 'node:assert';
import Parser from '../../parser';
import ServiceAnalyzer from '../analyzer.service';
import Graph from '../../graph';

describe("analyze services", () => {
	it("analyze @service and @event", async () => {
		const graph = new Graph();
		const parser = new Parser(graph);
		const analyzer = new ServiceAnalyzer(graph, {
			async scanFile() {},
			async scanModule() {},
		});

		const ast = parser.parse("init.ts", `
			@service
			class Init {
				@event
				OnceReady() {}
			}
		`);

		await analyzer.analyze(ast);

		assert.equal(graph.services.length, 1);
		assert.equal(graph.services[0].symbol.id, 'Init');

		assert.equal(graph.events.length, 1);
		assert.equal(graph.events[0].type, 'ready');
		assert.equal(graph.events[0].once, true);
		assert.equal(graph.events[0].symbol.id, 'OnceReady');
	});

	it("analyze @injectable", async () => {
		const graph = new Graph();
		const parser = new Parser(graph);
		const analyzer = new ServiceAnalyzer(graph, {
			async scanFile() {},
			async scanModule() {},
		});

		const ast = parser.parse("deinit.ts", `
			@injectable
			class Deinit {}
		`);

		await analyzer.analyze(ast);

		assert.equal(graph.injectables.length, 1);
		assert.equal(graph.injectables[0].symbol.id, 'Deinit');
		assert.deepEqual(graph.injectables[0].dependencies, []);
	});
});
