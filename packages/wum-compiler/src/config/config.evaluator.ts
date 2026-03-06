import * as vite from "vite";
import { Config, ModuleConfig, UserConfig } from "./config.dto";
import { basename, join as j } from "node:path";
import { RollupOptions } from 'rollup';
import path from 'node:path';

/**
 * Walk around config object and execute instructions based in
 */
export class ConfigEvaluator {
	config!: Config;

	evalModule(config: UserConfig) {
		this.config = config as Config;

		this.evalPaths(config);

		return this.config as ModuleConfig;
	}

	eval(config: UserConfig) {
		this.config = config as Config;

		this.evalPaths(config);
		this.evalVite(config.vite ??= {}, config.cwd!);

		return this.config as Config
	}

	private evalPaths(config: UserConfig) {
		config.cwd ??= process.cwd();
		config.entryPath ??= "src";
		config.buildPath ??= ".wum";
		config.commandsPath ??= "commands/**/*.tsx";
		config.servicesPath ??= "services/**/*.{ts,tsx}";
	}

	private evalVite(config: vite.UserConfig, cwd: string) {
		config.base = './';
		config.esbuild ??= {};
		config.esbuild.jsx = "automatic";
		config.esbuild.jsxImportSource ??= "wum";
		config.build ??= {};
		config.build.outDir = j(cwd, this.config.buildPath!);

		const rollup = config.build.rollupOptions ??= {};

		this.evalRollupInput(rollup);
		this.evalRollupExternal(rollup);
		this.evalRollupOutput(rollup, cwd);
	}

	private evalRollupInput(rollup: RollupOptions) {
		rollup.preserveEntrySignatures = "allow-extension";

		let input = rollup.input;
		if (input && !Array.isArray(input) && typeof input === "object") {
			throw new Error("Rollup input as object is not supported");
		}
		if (typeof input === "string") {
			input = [input];
		}
		rollup.input ??= [];

		(rollup.input as any[]).push(
			'virtual:index',
			'virtual:commands.tsx',
			'virtual:manifest'
		);
	}

	private evalRollupExternal(rollup: RollupOptions) {
		rollup.external = (id) => {
			if (id.startsWith('\0')) return false;
			if (id.startsWith('virtual:')) return false;
			if (id.startsWith('./') || id.startsWith('../')) return false;

			if (path.isAbsolute(id)) {
				const relativeToCwd = path.relative(this.config.cwd!, id);
				const isInsideCwd = !relativeToCwd.startsWith('..') && !path.isAbsolute(relativeToCwd);
				return !isInsideCwd;
			}

			return true;
		};
	}

	private evalRollupOutput(rollup: RollupOptions, cwd: string) {
		const output = rollup.output ??= {};

		if (Array.isArray(output)) {
			throw new Error("Rollup output as array is not supported");
		}

		output.preserveModules = true;
		output.format = "esm";
		output.virtualDirname = output.dir;
		(output.entryFileNames as any) = (chunk: vite.Rollup.PreRenderedChunk) => {
			const moduleId = chunk.facadeModuleId ?? '';
			const pattern = j(this.config.entryPath, this.config.servicesPath);
			
			if (moduleId.startsWith('virtual:')) {
				return moduleId
					.split(':')[1]
					.replace(/\.[^.]+$/, '')
					+ '.js';
			}
			else if (path.matchesGlob(moduleId, pattern)) {
				return `managers/${basename(moduleId)}.js`;
			}

			return '[name].js'
		}

		rollup.output = output;
	}
}
