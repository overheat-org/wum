import { NodePath } from "@babel/traverse";
import traverse from "../utils/traverse";
import * as T from "@babel/types";
import { WumError } from "@wum/shared";
import { AnalyzerInstruction as BaseInstruction } from "./analyzer.dto";

export enum InstructionKind {
	Import,
	ExportDefault,
}

export type AnalyzerInstruction =
	| BaseInstruction<InstructionKind.Import, NodePath<T.ImportDeclaration>>
	| BaseInstruction<InstructionKind.ExportDefault, NodePath<T.ExportDefaultDeclaration>>;

class CommandAnalyzer {
	analyze(ast: T.File): AnalyzerInstruction[] {
		const result = new Array;
		
		const bindFn = (fn: (...args: any[]) => unknown, path: NodePath) => {
			result.push(fn.call(this, path));
		}
		
		traverse(ast, {
			TSEnumDeclaration: p => bindFn(this.analyzeEnum, p),
			ClassDeclaration: p => bindFn(this.analyzeClass, p),
			ExportDefaultDeclaration: p => bindFn(this.analyzeExportDefault, p),
			ExportNamedDeclaration: p => bindFn(this.analyzeExportNamed, p)
		});

		return result;
	}

	private analyzeEnum(path: NodePath<T.TSEnumDeclaration>) {
		throw new WumError('Cannot use enum in command', path);
	}

	private analyzeClass(path: NodePath<T.ClassDeclaration>) {
		throw new WumError('Cannot use class in command', path);
	}

	private analyzeExportDefault(path: NodePath<T.ExportDefaultDeclaration>) {
		const decl = path.get("declaration");
		
		if(
			decl.isObjectExpression() ||
			decl.isJSXElement()
		) return;

		throw new WumError(`Cannot export by default a non-command element`, path);
	}

	private analyzeExportNamed(path: NodePath<T.ExportNamedDeclaration>) {
		const decl = path.get('declaration');

		if(decl.isDeclaration()) {
			throw new WumError('Cannot export in command', decl);
		}
		
		for(const specifier of path.get('specifiers')) {
			// @ts-ignore
			if(specifier.node.id.name == 'default') continue;
			
			throw new WumError('Cannot export in command', specifier);
		}
	}
}

export default CommandAnalyzer;