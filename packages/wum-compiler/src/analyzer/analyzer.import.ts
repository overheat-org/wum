import { NodePath } from "@babel/traverse";
import * as T from "@babel/types";
import { resolveNodeId } from "../utils/id-resolver";
import Scanner from "../scanner";
import Graph from "../graph";
import { FileTypes } from "@wum/shared";
import { ImportResolver } from "../import-resolver";

// TODO: Talvez seja melhor fazer o scanModule retornar a lista de symbols encontrados no arquivo

export class ImportAnalyzer {
	resolver = new ImportResolver();
	
	constructor(private graph: Graph, private scanner: Scanner) {}
	
	async analyzeTypeDeclaration(path: NodePath<T.TSTypeReference>) {
		const typeName = resolveNodeId(path.get("typeName")).node.name;
		const binding = path.scope.getBinding(typeName);

		await this.analyzeBinding(binding?.path);

		const symbols = this.graph.getSymbolsByModule(path.node.loc!.filename)

		return symbols.find(s => s.id == typeName);
	}

	analyzeBinding(path?: NodePath<T.Node>) {
		switch (path?.node.type) {
			case "ImportDefaultSpecifier":
			case "ImportSpecifier":
				return this.analyzeSpecifier(path as NodePath<
					| T.ImportDefaultSpecifier
					| T.ImportSpecifier
				>);
		}
	}

	async analyzeSpecifier(spec: NodePath<T.ImportSpecifier | T.ImportDefaultSpecifier>) {
		const decl = spec.parentPath.node as T.ImportDeclaration;
		const source = decl.source.value;
		const fromFile = spec.node.loc?.filename ?? "";

		const resolved = await this.resolver.resolve(source, fromFile);

		if (resolved.kind === "file") {
			return this.scanner.scanFile(resolved.path, FileTypes.Service);
		}

		if (resolved.kind === "module") {
			return this.scanner.scanModule(resolved.root);
		}
	}
}