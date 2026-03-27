import { builtinModules } from "node:module";
import { defineConfig } from "bunup";
import { name, version } from "./package.json";

const builtins = [...builtinModules, ...builtinModules.map((module) => `node:${module}`)];
const babelPackages = [
	"@babel/generator",
	"@babel/parser",
	"@babel/traverse",
	"@babel/types",
];

export default defineConfig({
	entry: ["src/index.ts"],
	outDir: "lib",
	sourceBase: "src",
	format: "esm",
	target: "node",
	dts: true,
	packages: "external",
	external: [...builtins, "vite", ...babelPackages],
	noExternal: ["@wumjs/shared"],
	define: {
		__NAME__: JSON.stringify(name),
		__VERSION__: JSON.stringify(version),
	},
});
