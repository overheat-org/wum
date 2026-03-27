import { builtinModules } from "node:module";
import { defineConfig } from "bunup";

const builtins = [...builtinModules, ...builtinModules.map((module) => `node:${module}`)];

export default defineConfig({
	entry: ["src/index.ts"],
	outDir: "lib",
	sourceBase: "src",
	format: "esm",
	target: "node",
	packages: "external",
	external: builtins,
	noExternal: ["@wumjs/compiler", "@wumjs/shared"],
});
