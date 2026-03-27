import * as T from '@babel/types';
import Graph from "../graph";
import Scanner from "../scanner";
import Parser from "../parser";
import { CommandTransformer } from "./transformer.command";
import { ServiceTransformer } from "./transformer.service";
import { FileTypes } from '@wumjs/shared';
import { NodePath } from '@babel/traverse';

class Transformer {
	private services?: ServiceTransformer;
	private commands: CommandTransformer;

	constructor(private graph: Graph, parser: Parser) {
		this.commands = new CommandTransformer();
	}

	set scanner(scanner: Scanner) {
		this.services = new ServiceTransformer(this.graph, scanner);
	}

	transform(type: FileTypes, ast: NodePath<T.Program>) {
		return {
			[FileTypes.Command]: () => this.commands.transform(ast),
			[FileTypes.Service]: () => {
				if (!this.services) {
					throw new Error("Service transformer is not initialized");
				}
				return this.services.transform(ast);
			}
		}[type]();
	}
}

export default Transformer;
