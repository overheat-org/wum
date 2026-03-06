import * as T from '@babel/types';
import CommandAnalyzer, { InstructionKind } from '../analyzer/analyzer.command';
import { NodePath } from '@babel/traverse';
import nodePath from 'node:path';

export class CommandTransformer {
	private analyzer = new CommandAnalyzer();

	transform(ast: NodePath<T.Program>) {
		const instructions = this.analyzer.analyze(ast);

		const map = {
			[InstructionKind.Import]: this.transformImport,
			[InstructionKind.ExportDefault]: this.transformExportDefault,
		};

		for (const instruction of instructions) {
			map[instruction.kind].call(this, instruction.value);
		}
	}

	transformImport(path: NodePath<T.ImportDeclaration>) {
		let source = path.node.source.value;
		if (source.includes('/managers/')) {
			source = source.replace('/managers/', '/services/');
		}
		if (source.startsWith('./') || source.startsWith('../')) {
			const fromFile = path.node.loc?.filename;
			if (fromFile) {
				source = nodePath.resolve(nodePath.dirname(fromFile), source);
			}
		}
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

		parent.node.body = [
			T.exportDefaultDeclaration(
				T.functionExpression(
					null,
					[],
					T.blockStatement(parent.node.body),
					false,
					true
				)
			)
		];
	}
}
