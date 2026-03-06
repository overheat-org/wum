import { afterEach, describe, it, mock } from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs/promises';
import { FileTypes } from '@wum/shared';
import Graph from '../graph';
import Parser from '../parser';
import Scanner from '../scanner';
import Transformer from '../transformer';
import CodeGenerator from '../codegen';

describe("scanner", () => {
	afterEach(() => {
		mock.restoreAll();
	});

	it("scanFile should cache command file and add one command", async () => {
		const graph = new Graph();
		const parser = new Parser(graph);
		const transformer = new Transformer(graph, parser);
		const codegen = new CodeGenerator(graph);
		const scanner = new Scanner(graph, parser, codegen, transformer);

		let transformCalls = 0;
		mock.method(transformer, "transform", async () => {
			transformCalls++;
		});

		let readCalls = 0;
		mock.method(fs, "readFile", async () => {
			readCalls++;
			return `export default <command name="ping"></command>;`;
		});

		await scanner.scanFile("/repo/src/commands/ping.tsx", FileTypes.Command);
		await scanner.scanFile("/repo/src/commands/ping.tsx", FileTypes.Command);

		assert.equal(readCalls, 1);
		assert.equal(transformCalls, 1);
		assert.equal(graph.commands.length, 1);
	});

	it("scanFile should emit transformed service file", async () => {
		const graph = new Graph();
		const parser = new Parser(graph);
		const transformer = new Transformer(graph, parser);
		const codegen = new CodeGenerator(graph);
		const scanner = new Scanner(graph, parser, codegen, transformer);

		mock.method(transformer, "transform", async () => {});
		mock.method(fs, "readFile", async () => `export class Init {}`);
		mock.method(codegen, "generateCode", () => `// transformed service`);

		const servicePath = "/repo/src/services/init.ts";
		await scanner.scanFile(servicePath, FileTypes.Service);

		assert.equal(graph.getFile(servicePath), "// transformed service");
		assert.equal(graph.commands.length, 0);
	});
});
