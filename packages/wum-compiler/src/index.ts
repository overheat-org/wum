import * as vite from 'vite';
import Scanner from './scanner';
import Graph from './graph';
import Parser from './parser';
import Transformer from './transformer';
import CodeGenerator from './codegen';
import BridgePlugin from './plugin';

class Compiler {
	private graph = new Graph();
	private parser = new Parser(this.graph);
	private transformer = new Transformer(this.graph, this.parser);
	private codegen = new CodeGenerator(this.graph);
    private scanner = new Scanner(this.codegen, this.transformer);

	constructor() {
		this.transformer.scanner = this.scanner;
	}

    async build(cwd = process.cwd()) {
        const config = await this.scanner.scanRootModule(cwd);
		(config.vite!.plugins ??= []).unshift(BridgePlugin(this.graph, this.codegen, config));
		
        await vite.build(config.vite);
    }
}

export default Compiler;