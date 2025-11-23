import * as T from '@babel/types';
import CommandAnalyzer, { InstructionKind } from '../analyzer/analyzer.command';
import { NodePath } from '@babel/traverse';

export class CommandTransformer {
	private analyzer = new CommandAnalyzer();

	transform(ast: T.File) {
		const instructions = this.analyzer.analyze(ast);

		const map = {
			[InstructionKind.Import]: this.transformImport,
			[InstructionKind.ExportDefault]: this.transformExportDefault,
		};

		for (const instruction of instructions) {
			map[instruction.kind].bind(this, instruction.value);
		}
	}

	transformImport(path: NodePath<T.ImportDeclaration>) {
		const source = path.node.source.value;
		const specifiers = path.node.specifiers;

		const importExpressions = specifiers.map(specifier => {
			if (T.isImportDefaultSpecifier(specifier)) {
				return T.variableDeclaration("const", [
					T.variableDeclarator(
						specifier.local,
						T.memberExpression(
							T.awaitExpression(T.callExpression(T.import(), [T.stringLiteral(source)])),
							T.identifier("default")
						)
					)
				]);
			}

			if (T.isImportSpecifier(specifier)) {
				return T.variableDeclaration("const", [
					T.variableDeclarator(
						specifier.local,
						T.memberExpression(
							T.awaitExpression(T.callExpression(T.import(), [T.stringLiteral(source)])),
							specifier.imported
						)
					)
				]);
			}
		});

		path.replaceWithMultiple(importExpressions as any);
	}

	transformExportDefault(path: NodePath<T.ExportDefaultDeclaration>) {
		const parent = path.parentPath as NodePath<T.Program>;

		path.replaceWith(
			T.returnStatement(path.node.declaration)
		);

		parent.replaceWith(
			T.callExpression(
				T.functionExpression(
					null,
					[],
					T.blockStatement(parent.node.body)
				),
				[]
			)
		);
	}
}