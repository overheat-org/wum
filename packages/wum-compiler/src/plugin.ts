import { Plugin } from 'rollup';
import CodeGenerator from './codegen';
import Graph from './graph';
import { Config } from './config';

declare const __NAME__: string;
declare const __VERSION__: string;

/**
 * Intercept transformation of code in vite process
 */
function BridgePlugin(graph: Graph, codegen: CodeGenerator, config: Config) {
	return {
		name: __NAME__,
		version: __VERSION__,
		buildEnd() {
			codegen.emitCommands(this);
		},
		resolveId(id) {
			return id;
		},
		async load(path) {
			if (path === 'virtual:index') {
				return codegen.generateIndex();
			}
			if (path === 'virtual:manifest') {
				return codegen.generateManifest(config.buildPath);
			}
			return graph.getFile(path);
		},
	} satisfies Plugin;
}

export default BridgePlugin;
