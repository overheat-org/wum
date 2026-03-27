import { builtinModules } from "node:module";
import { defineConfig } from "bunup";

const builtins = [...builtinModules, ...builtinModules.map((module) => `node:${module}`)];

export default defineConfig({
	entry: [
		"src/index.ts",
		"src/hooks.ts",
		"src/jsx-runtime.ts",
		"src/cli.ts",
	],
	outDir: "lib",
	sourceBase: "src",
	format: "esm",
	target: "node",
	dts: true,
	packages: "external",
	external: builtins,
	noExternal: ["@wum/cli", "@wum/compiler", "@wum/runtime", "@wum/shared"],
});
