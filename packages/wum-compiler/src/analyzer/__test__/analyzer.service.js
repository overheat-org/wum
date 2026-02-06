import fs from 'fs/promises';
import { describe, it, mock } from 'node:test';
import assert from 'node:assert';
import Parser from '../../parser';
import ServiceAnalyzer from '../analyzer.service';
import Graph from '../../graph';
import Scanner from '../../scanner';
import CodeGenerator from '../../codegen';

describe("analyze services", async () => {
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
	const codegen = new CodeGenerator(graph);
	const scanner = new Scanner(codegen, { transform() {} });

	mock.method(fs, 'readFile', function(path, _) {
		return Promise.resolve(files[path]);
	});

	mock.method(fs, 'readdir', function(path) {
		return Promise.resolve(Object.keys(files));
	});

	for(const path in files) {
		const content = files[path];

		await scanner.scanFile(path, content);
	}

	const { services, injectables } = graph;
	
	const service = services[0];
	
	it("analyze @service", () => {
		assert.equal(services.length, 1);
		assert.equal(service.symbol.id, 'Init');
	});
	
	const dependency = service?.dependencies?.[0];
	const injectable = injectables[0];
	
	// it("analyze @injectable", () => {
	// 	assert.equal(injectables.length, 1);
	// 	assert.equal(injectable, dependency);
	// 	assert.equal(injectable.symbol.id, 'Deinit');
	// 	assert.equal(injectable.dependencies.length, 0);
	// });
});