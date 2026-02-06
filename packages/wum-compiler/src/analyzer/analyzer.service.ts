import * as T from '@babel/types';
import { NodePath } from "@babel/traverse";
import { HTTP_METHODS } from "@wum/shared";
import { AnalyzerInstruction as BaseInstruction, DecoratorSchema, DecoratorType, MacroDecorator } from './analyzer.dto';
import MacroAnalyzer from './analyzer.macro';
import { DependencyAnalyzer } from './analyzer.dependency';
import Graph from '../graph';
import { ImportAnalyzer } from './analyzer.import';
import Scanner from '../scanner';

export enum InstructionKind {
	MacroDecorator,
}

export type AnalyzerInstruction = BaseInstruction<
	InstructionKind.MacroDecorator, 
	MacroDecorator
>;

const decoratorRules = [
	{
		name: 'injectable',
		class: true
	},
	{
		name: 'service',
		class: true
	},
	{
		name: 'http',
		children: HTTP_METHODS.map(method => ({
			name: method,
			method: true,
		}))
	},
	{
		name: 'event',
		method: true
	}
] as DecoratorSchema[];

class ServiceAnalyzer {
	private importAnalyzer: ImportAnalyzer;
	private dependencyAnalyzer: DependencyAnalyzer;
	private macroAnalyzer: MacroAnalyzer;

	constructor(private graph: Graph, scanner: Scanner) {
		this.importAnalyzer = new ImportAnalyzer(graph, scanner);
		this.dependencyAnalyzer = new DependencyAnalyzer(this.importAnalyzer);
		this.macroAnalyzer = new MacroAnalyzer(this.dependencyAnalyzer, graph);
	}
	
	analyze(ast: NodePath<T.File>) {
		const result = new Array<AnalyzerInstruction>;

		const bindFn = (fn: (...args: any[]) => unknown, path: NodePath) => {
			const instruction = fn.call(this, path) as AnalyzerInstruction | undefined;
			if(instruction) result.push(instruction);
		}

		ast.traverse({
			Decorator: p => bindFn(this.analyzeDecorator, p),
		});

		return Promise.all(result);
	}

	async analyzeDecorator(path: NodePath<T.Decorator>): MacroDecorator | undefined {
		const expr = path.get("expression") as NodePath<T.Expression>;

		let rules = decoratorRules;
		let last: DecoratorSchema | undefined;
		let params: NodePath<T.Expression>[] = [];

		let cur: NodePath<T.Expression> | null = expr;

		while (cur) {
			if (cur.isMemberExpression()) {
				const obj = cur.get("object") as NodePath<T.Identifier>;
				last = rules.find(d => d.name === obj.node.name);
				rules = last?.children ?? [];
				cur = cur.get("property") as NodePath<T.Expression>;
				continue;
			}

			if (cur.isCallExpression()) {
				const callee = cur.get("callee") as NodePath<T.Identifier>;
				last = rules.find(d => d.name === callee.node.name);
				rules = last?.children ?? [];
				params = cur.get("arguments") as NodePath<T.Expression>[];
				cur = null;
				continue;
			}

			if (cur.isIdentifier()) {
				last = rules.find(d => d.name === cur?.node.name);
				rules = last?.children ?? [];
				cur = null;
				continue;
			}

			break;
		}

		if (!last) return undefined;

		const parent = path.parentPath;

		let macro: MacroDecorator | undefined;

		if (parent.isClassDeclaration()) {
			macro = {
				schema: last,
				params: params.map(p => p.node),
				decorator: path,
				type: DecoratorType.Class,
				target: parent as NodePath<T.Class>,
			};
		}

		if (parent.isClassMethod()) {
			macro = {
				schema: last,
				params: params.map(p => p.node),
				decorator: path,
				type: DecoratorType.Method,
				target: parent as NodePath<T.ClassMethod>,
			};
		}

		if(macro) {
			await this.macroAnalyzer.analyze(macro);
		}

		return undefined;
	}
}

export default ServiceAnalyzer;