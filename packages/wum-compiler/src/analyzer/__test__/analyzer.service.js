import { describe, it } from 'node:test';
import assert from 'node:assert';
import Parser from '../../parser';
import ServiceAnalyzer from '../analyzer.service';
import Graph from '../../graph';

describe("analyze services", () => {
	const files = {
		'init.ts': `
			import Deinit from './deinit.ts';
		
			@service
			class Init {
				constructor(private deinit: Deinit) {}
			}
		`,
		'deinit.ts': `
			@injectable
			export class Deinit {
				constructor() {}
			}
		`
	}
	
	const graph = new Graph();
	const parser = new Parser();
	const analyzer = new ServiceAnalyzer(graph, {
		scanFile(path, type) {
			return files['deinit.ts'];
		}
	});

	const { services, injectables } = graph;

	for(const path in files) {
		const content = files[path];

		const ast = parser.parse(path, content);

		analyzer.analyze(ast);
	}
	
	const service = services[0];
	const injectable = injectables[0];
	
	it("analyze @service", () => {
		assert.equal(services.length, 1);
		assert.equal(service.symbol.id, 'Init');
	});
	
	const dependency = service?.dependencies?.[0];
	
	it("analyze @injectable", () => {
		assert.equal(injectables.length, 1);
		assert.equal(injectable, dependency);
		assert.equal(injectable.symbol.id, 'Deinit');
		assert.equal(injectable.dependencies.length, 0);
	});
});