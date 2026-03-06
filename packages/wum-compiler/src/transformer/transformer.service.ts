import * as T from '@babel/types';
import { InstructionKind, MacroDecorator } from '../analyzer/analyzer.dto';
import ServiceAnalyzer from '../analyzer/analyzer.service';
import Graph from '../graph';
import Scanner from '../scanner';
import { NodePath } from '@babel/traverse';

export class ServiceTransformer {
	private analyzer: ServiceAnalyzer;

	constructor(graph: Graph, scanner: Scanner) {
		this.analyzer = new ServiceAnalyzer(graph, scanner);
	}

	async transform(ast: NodePath<T.Program>) {
		const instructions = await this.analyzer.analyze(ast);
		
		const map = {
			[InstructionKind.MacroDecorator]: this.transformMacroDecorator
		}

		for(const instruction of instructions) {
			map[instruction.kind].call(this, instruction.value);
		}
	}
	
	transformMacroDecorator(ctx: MacroDecorator) {
		ctx.decorator.remove();
	}
}
