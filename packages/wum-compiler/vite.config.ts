import { defineConfig } from "vite";
import path from "path";
import { builtinModules as _b } from "module";

const builtinModules = [..._b, ..._b.map(m => 'node:' + m)];

export default defineConfig({
	build: {
		lib: {
			entry: path.resolve(__dirname, "src/index.ts"),
			formats: ["es"],
			fileName: "index",
		},
		outDir: "lib",
		rollupOptions: {
			external: [...builtinModules, "vite"], // todos os built-ins + CJS problemático
		},
		sourcemap: true,
		target: "node16",
	},
	optimizeDeps: {
		disabled: true,
	},
});
