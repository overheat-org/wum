import { defineConfig } from "bunup";

export default defineConfig({
	entry: ["src/index.ts"],
	outDir: "lib",
	sourceBase: "src",
	format: "esm",
	target: "node",
	dts: true,
	packages: "external",
});
