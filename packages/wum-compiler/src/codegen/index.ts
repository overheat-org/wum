import * as T from '@babel/types';
import ManifestGenerator from './gen.manifest';
import IndexGenerator from './gen.index';
import Graph from '../graph';
import _generate from '@babel/generator';
import { PluginContext } from 'rollup';

const generate = ('default' in _generate ? _generate.default : _generate) as typeof _generate;

class CodeGenerator {
	private generators: {
		commands: CommandsGenerator,
		manifest: ManifestGenerator,
		index: IndexGenerator
	}

	constructor(graph: Graph) {
		this.generators = {
			commands: new CommandsGenerator(),
			manifest: new ManifestGenerator(graph),
			index: new IndexGenerator(),
		}
	}
	
	emitCommands(ctx: PluginContext) {
		const ast = this.generators.commands.generate();

		ctx.emitFile({
			type: 'asset',
			source: this.generateCode(ast),
			fileName: 'commands.js'
		});
	}

	generateIndex() {
		return this.generators.index.generate();
	}

	generateManifest() {
		return this.generateCode(
			this.generators.manifest.generate()
		);
	}

	generateCode(ast: T.Node) {
		return generate(ast).code;
	}
}

export default CodeGenerator;