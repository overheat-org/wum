import { parse } from '@babel/parser';
import * as T from '@babel/types';
import Graph from './graph';
import traverse from './utils/traverse';
import { NodePath } from '@babel/traverse';

class Parser {
	constructor(private graph: Graph) { }

	private declarations = new Map<string, T.Statement>();

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

		traverse(ast, {
			File: (nodePath) => {
				result = nodePath;
				
				this.parseDeclarations(nodePath.node.program.body);
			}
		});

		ast.program.body.forEach(stmt => {
			const handler = this.map[stmt.type as keyof typeof this.map];
			if (handler) {
				handler.call(this, stmt as any);
			}
		});

		return result;
	}

	private parseDeclarations(body: T.Statement[]) {
		for (const stmt of body) {
			switch (stmt.type) {
				case 'VariableDeclaration': {
					for (const decl of stmt.declarations) {
						if (T.isIdentifier(decl.id)) {
							this.declarations.set(decl.id.name, stmt);
						}
					}
					break;
				}
				case 'FunctionDeclaration': {
					if (stmt.id) {
						this.declarations.set(stmt.id.name, stmt);
					}
					break;
				}
				case 'ClassDeclaration': {
					if (stmt.id) {
						this.declarations.set(stmt.id.name, stmt);
					}
					break;
				}
				case 'TSInterfaceDeclaration': {
					this.declarations.set(stmt.id.name, stmt);
					break;
				}
				case 'TSTypeAliasDeclaration': {
					this.declarations.set(stmt.id.name, stmt);
					break;
				}
				case 'TSEnumDeclaration': {
					this.declarations.set(stmt.id.name, stmt);
					break;
				}
			}
		}
	}

	private parseExportNamed(exportNamed: T.ExportNamedDeclaration) {
		const { declaration, specifiers } = exportNamed;

		if (declaration) {
			const resolvedId = this.parseId(declaration);
			if (resolvedId) {
				this.graph.addSymbol({
					node: declaration,
					kind: declaration.type,
					id: resolvedId.name,
				});
			}
		}

		if (specifiers.length === 0) return;

		for (const specifier of specifiers) {
			if (specifier.type === 'ExportSpecifier') {
				const localDecl = this.declarations.get(specifier.local.name);
				if (localDecl) {
					this.graph.addSymbol({
						node: localDecl,
						kind: localDecl.type,
						id: specifier.exported.name,
					});
				}
			}
		}
	}

	private parseExportAll(exportAll: T.ExportAllDeclaration) {
		if (exportAll.source) {
			console.log(`Re-exporting all from: ${exportAll.source.value}`);
		}
	}

	private parseExportDefault(exportDefault: T.ExportDefaultDeclaration) {
		const { declaration } = exportDefault;

		if (T.isIdentifier(declaration)) {
			this.graph.addSymbol({
				node: exportDefault,
				kind: 'ExportDefaultDeclaration',
				id: 'default',
			});
		} else {
			const resolvedId = this.parseId(declaration);

			this.graph.addSymbol({
				node: declaration,
				kind: declaration.type,
				id: resolvedId?.name ?? 'default',
			});
		}
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