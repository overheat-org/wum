import * as T from '@babel/types';
import Graph from "../graph";
import Analyzer from "../analyzer";
import Scanner from "../scanner";
import Parser from "../parser";
import { CommandTransformer } from "./transformer.command";
import { ServiceTransformer } from "./transformer.service";
import { FileTypes } from '@wum/shared';

class Transformer {
	private services: ServiceTransformer;
	private commands: CommandTransformer;

	constructor(private graph: Graph, scanner: Scanner, parser: Parser) {
		this.commands = new CommandTransformer(this.analyzer);
		this.services = new ServiceTransformer(this.analyzer);
	}

	transform(type: FileTypes, ast: T.File) {
		return {
			[FileTypes.Command]: () => this.commands.transform(ast),
			[FileTypes.Service]: () => this.services.transform(ast)
		}[type]();
	}
}

export default Transformer;
