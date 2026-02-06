import * as T from '@babel/types';
import Graph from "../graph";
import Scanner from "../scanner";
import Parser from "../parser";
import { CommandTransformer } from "./transformer.command";
import { ServiceTransformer } from "./transformer.service";
import { FileTypes } from '@wum/shared';
import { NodePath } from '@babel/traverse';

class Transformer {
	private services: ServiceTransformer;
	private commands: CommandTransformer;
	public scanner!: Scanner

	constructor(private graph: Graph, parser: Parser) {
		this.commands = new CommandTransformer();
		this.services = new ServiceTransformer(graph, this.scanner);
	}

	transform(type: FileTypes, ast: NodePath<T.Program>) {
		return {
			[FileTypes.Command]: () => this.commands.transform(ast),
			[FileTypes.Service]: () => this.services.transform(ast)
		}[type]();
	}
}

export default Transformer;
