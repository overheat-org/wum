import { NodePath } from "@babel/traverse";
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
	analyze(ast: NodePath<T.Program>): AnalyzerInstruction[] {
		const result = new Array<AnalyzerInstruction>;
		
		const bindFn = (fn: (...args: any[]) => unknown, path: NodePath) => {
			const instruction = fn.call(this, path) as AnalyzerInstruction | undefined;
			if(instruction) result.push(instruction);
		}

		ast.traverse({
			ImportDeclaration: p => bindFn(this.analyzeImport, p),
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
		) {
			return {
				kind: InstructionKind.ExportDefault,
				value: path
			};
		}

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

	private analyzeImport(path: NodePath<T.ImportDeclaration>) {
		return {
			kind: InstructionKind.Import,
			value: path
		};
	}
}

export default CommandAnalyzer;
