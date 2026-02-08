import { parse } from '@babel/parser';
import * as T from '@babel/types';
import Graph from './graph';
import traverse from './utils/traverse';
import { NodePath } from '@babel/traverse';

class Parser {
	constructor(private graph: Graph) { }

	private declarations = new Map<string, NodePath<T.Node>>();

	private map = {
		ExportNamedDeclaration: this.parseExportNamed,
		ExportAllDeclaration: this.parseExportAll,
		ExportDefaultDeclaration: this.parseExportDefault,
	} as const;

	parse(path: string, content: string) {
		const ast = parse(content, {
			sourceType: 'module',
			sourceFilename: path,
			plugins: ["decorators", "typescript", "jsx"],
			errorRecovery: true
		});

		let result!: NodePath<T.File>;
		let programPath!: NodePath<T.Program>;

		traverse(ast, {
			File: (nodePath) => {
				result = nodePath;

				programPath = nodePath.get("program") as NodePath<T.Program>;
				this.parseDeclarations(programPath);
			}
		});

		const body = programPath.get("body") as NodePath<T.Statement>[];
		for (const stmtPath of body) {
			const handler = this.map[stmtPath.node.type as keyof typeof this.map];
			if (handler) {
				handler.call(this, stmtPath as any);
			}
		}

		return result;
	}

	private parseDeclarations(programPath: NodePath<T.Program>) {
		const body = programPath.get("body") as NodePath<T.Statement>[];

		for (const stmtPath of body) {
			if (stmtPath.isVariableDeclaration()) {
				const declarations = stmtPath.get("declarations") as NodePath<T.VariableDeclarator>[];
				for (const declPath of declarations) {
					const idPath = declPath.get("id");
					if (idPath.isIdentifier()) {
						this.declarations.set(idPath.node.name, stmtPath);
					}
				}
				continue;
			}

			if (stmtPath.isFunctionDeclaration() || stmtPath.isClassDeclaration()) {
				const idPath = stmtPath.get("id");
				if (idPath && idPath.isIdentifier()) {
					this.declarations.set(idPath.node.name, stmtPath);
				}
				continue;
			}

			if (
				stmtPath.isTSInterfaceDeclaration() ||
				stmtPath.isTSTypeAliasDeclaration() ||
				stmtPath.isTSEnumDeclaration()
			) {
				const idPath = stmtPath.get("id");
				if (idPath && idPath.isIdentifier()) {
					this.declarations.set(idPath.node.name, stmtPath);
				}
			}
		}
	}

	private parseExportNamed(exportNamedPath: NodePath<T.ExportNamedDeclaration>) {
		const declarationPath = exportNamedPath.get("declaration") as NodePath<T.Declaration> | null;
		const specifiers = exportNamedPath.get("specifiers") as NodePath<T.ExportSpecifier>[];

		if (declarationPath && declarationPath.node) {
			const resolvedId = this.parseId(declarationPath.node);
			if (resolvedId) {
				this.graph.addSymbol({
					node: declarationPath,
					kind: declarationPath.node.type,
					id: resolvedId.name,
				});
			}
		}

		if (specifiers.length === 0) return;

		for (const specifierPath of specifiers) {
			const localName = specifierPath.node.local.name;
			const exportedName = specifierPath.node.exported.name;

			const localDecl =
				this.declarations.get(localName) ??
				(specifierPath.scope.getBinding(localName)?.path as NodePath<T.Node> | undefined);

			if (localDecl) {
				this.graph.addSymbol({
					node: localDecl,
					kind: localDecl.node.type,
					id: exportedName,
				});
			} else {
				this.graph.addSymbol({
					node: specifierPath,
					kind: exportNamedPath.node.type,
					id: exportedName,
				});
			}
		}
	}

	private parseExportAll(exportAllPath: NodePath<T.ExportAllDeclaration>) {
		this.graph.addSymbol({
			node: exportAllPath,
			kind: exportAllPath.node.type,
			id: '*',
		});
	}

	private parseExportDefault(exportDefaultPath: NodePath<T.ExportDefaultDeclaration>) {
		const declarationPath = exportDefaultPath.get("declaration") as NodePath<
			T.Declaration | T.Expression
		>;

		if (declarationPath.isIdentifier()) {
			this.graph.addSymbol({
				node: exportDefaultPath,
				kind: exportDefaultPath.node.type,
				id: 'default',
			});
			return;
		}

		const resolvedId = this.parseId(declarationPath.node);

		this.graph.addSymbol({
			node: declarationPath,
			kind: declarationPath.node.type,
			id: resolvedId?.name ?? 'default',
		});
	}

	private parseId(elem: T.Node): T.Identifier | null {
		switch (elem.type) {
			case 'ClassDeclaration':
			case 'ClassExpression':
			case 'EnumDeclaration':
			case 'FunctionDeclaration':
			case 'FunctionExpression':
			case 'TSEnumDeclaration':
				return elem.id ?? null
			case 'ExpressionStatement':
				return this.parseId(elem.expression);
			case 'Identifier':
				return elem;
			case 'VariableDeclarator':
				return this.parseId(elem.id);
			default: 
				return null;
		}
	}
}

export default Parser;
