import * as T from '@babel/types';
import ManifestGenerator from './gen.manifest';
import IndexGenerator from './gen.index';
import Graph from '../graph';
import _generate from '@babel/generator';
import CommandsGenerator from './gen.commands';

const generate = ('default' in _generate ? _generate.default : _generate) as typeof _generate;

class CodeGenerator {
	private generators: {
		commands: CommandsGenerator,
		manifest: ManifestGenerator,
		index: IndexGenerator
	}

	constructor(graph: Graph) {
		this.generators = {
			commands: new CommandsGenerator(graph),
			manifest: new ManifestGenerator(graph),
			index: new IndexGenerator(),
		}
	}

	generateIndex() {
		return this.generators.index.generate();
	}

	generateCommands() {
		return this.generateCode(this.generators.commands.generate());
	}

	generateManifest(outputDir: string) {
		return this.generateCode(
			this.generators.manifest.generate(outputDir)
		);
	}

	generateCode(ast: T.Node) {
		return generate(ast).code;
	}
}

export default CodeGenerator;
