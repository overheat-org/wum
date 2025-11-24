import * as T from '@babel/types';
import Graph, { GraphSymbol, Route, Event, Service, Injectable, Module } from '../graph';
import { ManifestType } from '@extn/shared';
import { Config } from '../config';
import path from 'path';

type Item =
	| Event
	| Route
	| Service
	| Injectable
	| Module;

type Imports = [];

class ManifestGenerator {
	constructor(private graph: Graph, private config: Config) { }

	generate() {
		const importsAcc = new Array<Imports>;
		const obj = this.generateObject(importsAcc);
		const imports = this.generateImports(importsAcc);

		const file = T.file(
			T.program(
				...imports,
				T.exportDefaultDeclaration(obj)
			)
		);

		return file;
	}

	generateImports(symbols: GraphSymbol[]) {
		return symbols.map(symbol => {
			const id = T.identifier(symbol.id);
			const p = path.resolve(this.config.buildPath, symbol.path.getPathLocation())

			return T.importDeclaration(
				[T.importSpecifier(id, id)],
				T.stringLiteral(p)
			);
		});
	}

	generateObject(imports: Imports) {
		const allItems = [
			{
				key: ManifestType.Routes,
				items: this.graph.routes
			},
			{
				key: ManifestType.Dependencies,
				items: [...this.graph.modules, ...this.graph.services, ...this.graph.injectables]
			},
			{
				key: ManifestType.Events,
				items: this.graph.events
			},
		];

		const output: Record<string, T.ObjectExpression[]> = {};

		for (const group of allItems) {
			for (const item of group.items) {
				(output[group.key] ??= []).push(this.toAST(item));
				for (const s of this.getSymbols(item)) imports.push(s);
			}
		}

		return T.objectExpression(
			Object.entries(output).map(([k, v]) =>
				T.objectProperty(T.identifier(k), T.arrayExpression(v))
			)
		);
	}

	getSymbols(item: Item) {
		switch (item.kind) {
			case 'event':
			case 'route':
				return item.symbol.parent ? [item.symbol.parent] : [];

			case 'service':
			case 'injectable':
				return [item.symbol, ...item.dependencies];

			case 'module':
				return [...item.managers]
		}
	}

	toAST(item: Item) {
		switch (item.kind) {
			case 'event':
				return T.objectExpression([
					T.objectProperty(T.identifier("type"), T.stringLiteral(item.type)),
					T.objectProperty(T.identifier("once"), T.booleanLiteral(item.once)),
					T.objectProperty(T.identifier("handler"), T.stringLiteral(item.symbol.id)),
					T.objectProperty(
						T.identifier("entity"),
						T.identifier(item.symbol.parent?.id ?? "undefined")
					)
				]);

			case 'route':
				return T.objectExpression([
					T.objectProperty(T.identifier("endpoint"), T.stringLiteral(item.endpoint)),
					T.objectProperty(T.identifier("method"), T.stringLiteral(item.method)),
					T.objectProperty(T.identifier("ipc"), T.booleanLiteral(item.ipc)),
					T.objectProperty(T.identifier("handler"), T.stringLiteral(item.symbol.id)),
					T.objectProperty(T.identifier("entity"), T.identifier(item.symbol.parent?.id ?? "undefined"))
				]);

			case 'injectable':
			case 'service':
				return T.objectExpression([
					T.objectProperty(T.identifier("service"), T.identifier(item.symbol.id)),
					T.objectProperty(
						T.identifier("dependencies"),
						T.arrayExpression(item.dependencies.map(d => T.identifier(d.id)))
					)
				]);

			case 'module':
				return T.objectExpression([
					T.objectProperty(T.identifier("name"), T.stringLiteral(item.name)),
					T.objectProperty(T.identifier("managers"), T.arrayExpression(item.managers.map(m => T.identifier(m.id))))
				]);
		}
	}
}

export default ManifestGenerator;