import fs from "node:fs/promises";
import { join as j } from "node:path";
import { ConfigManager } from "./config/config.manager";
import Graph from "./graph";
import Transformer from "./transformer";
import { FileTypes } from "@wum/shared";
import Parser from "./parser";
import CodeGenerator from "./codegen";

class Scanner {
	constructor(private codegen: CodeGenerator, private transformer: Transformer) {}
	
	private graph = new Graph();
	private parser = new Parser(this.graph);
	private configManager = new ConfigManager();
	private limit = createLimit(8);

	async scanRootModule(path: string) {
		const config = await this.configManager.resolve(path);

		const basePath = j(path, config.entryPath);

		await Promise.all([
			this.scanGlob(config.commandsPath, { cwd: basePath, type: FileTypes.Command }),
			this.scanGlob(config.servicesPath, { cwd: basePath, type: FileTypes.Service }),
		]);

		return config;
	}

	async scanModule(path: string) {
		const config = await this.configManager.resolveModule(path);
		const basePath = j(path, config.entryPath);

		await Promise.all([
			this.scanGlob(config.commandsPath, { cwd: basePath, type: FileTypes.Command }),
			this.scanGlob(config.servicesPath, { cwd: basePath, type: FileTypes.Service }),
		]);
	}

	async scanGlob(pattern: string, opts: { type: FileTypes, cwd: string }) {
		for await (const path of fs.glob(pattern, { cwd: opts.cwd })) {
			await this.limit(() =>
                this.scanFile(j(opts.cwd, path), opts.type)
            );
		}
	}

	private scanCache = new Array<string>;

	async scanFile(path: string, type: FileTypes) {
		if(this.scanCache.includes(path)) return
		this.scanCache.push(path);

		const source = await this.readFile(path);
		const ast = this.parser.parse(path, source);
		await this.transformer.transform(type, ast);

		if(type == FileTypes.Command) {
			this.graph.addCommand(ast);
		}

		if(type == FileTypes.Service) {
			const content = this.codegen.generateCode(ast);
			this.graph.addFile(path, content);
		}
	}

	private readCache = new Map<string, string>;

	private async readFile(path: string) {
		if(this.readCache.has(path)) return this.readCache.get(path)!;

		const source = await fs.readFile(path, 'utf-8');

		this.readCache.set(path, source);

		return source;
	}
}

export default Scanner;

function createLimit(max: number) {
    let active = 0;
    const queue: (() => void)[] = [];

    const next = () => {
        active--;
        queue.shift()?.();
    };

    return async <T>(fn: () => Promise<T>): Promise<T> => {
        if (active >= max) {
            await new Promise<void>(r => queue.push(r));
        }
        active++;
        try {
            return await fn();
        } finally {
            next();
        }
    };
}
