import * as T from '@babel/types';
import { NodePath } from "@babel/traverse"
import { resolveNodeId } from "./utils/id-resolver.ts"

export interface Event {
	kind: "event"
	symbol: GraphSymbol
	type: string
	once: boolean
}

export interface Route {
	kind: "route"
	endpoint: string
	method: string
	symbol: GraphSymbol
	ipc: boolean
}

export interface Service {
	kind: "service"
	symbol: GraphSymbol
	dependencies: GraphSymbol[]
}

export interface Injectable {
	kind: "injectable"
	symbol: GraphSymbol;
	dependencies: GraphSymbol[];
}

export interface Module {
	kind: "module"
	name: string
	managers: GraphSymbol[]
}

export interface GraphSymbol {
	kind: string
	id: string
	path: NodePath
	parent?: GraphSymbol
}

/** @internal */
class Graph {
	private symbolsByFile = new Map<string, Set<WeakRef<GraphSymbol>>>();
	private symbolsByKey = new Map<string, WeakRef<GraphSymbol>>();

	private getSymbolKey(symbol: GraphSymbol): string {
		return `${symbol.path}:${symbol.id}`;
	}

	// fix: resolver o symbol node
	
	addSymbol(symbol: GraphSymbol) {
		const key = this.getSymbolKey(symbol);
		this.symbolsByKey.set(key, new WeakRef(symbol));

		let set = this.symbolsByFile.get(symbol.node);
		if (!set) {
			set = new Set();
			this.symbolsByFile.set(symbol.node, set);
		}
		set.add(new WeakRef(symbol));
		return symbol;
	}

	resolveSymbol(symbol: GraphSymbol | NodePath, parent?: GraphSymbol | NodePath) {
		if (symbol instanceof NodePath) {
			symbol = this.resolveSymbolFromNode(symbol);
		}

		if (parent instanceof NodePath) {
			parent = this.resolveSymbolFromNode(parent);
		}

		const key = this.getSymbolKey(symbol);
		const existing = this.symbolsByKey.get(key)?.deref();
		if (existing && parent) existing.parent = parent;

		return existing ?? this.addSymbol({ ...symbol, parent });
	}

	private resolveSymbolFromNode(node: NodePath) {
		const symbol: GraphSymbol = {
			node,
			id: resolveNodeId(node).node.name,
			kind: node.type,
			path: node.node.loc!.filename
		}

		return symbol;
	}

	getSymbolsByModule(path: string) {
		const set = this.symbolsByFile.get(path);
		if (!set) return [];

		const validSymbols: GraphSymbol[] = [];
		for (const ref of set) {
			const symbol = ref.deref();
			if (symbol) validSymbols.push(symbol);
			else set.delete(ref);
		}

		return validSymbols;
	}

	findSymbol(opts: { path: string, id: string }) {
		const set = this.symbolsByFile.get(opts.path);
		if (!set) return null;

		for (const ref of set) {
			const symbol = ref.deref();
			if (symbol && symbol.id === opts.id) return symbol;
		}
		return null;
	}

	private fileByPath = new Map<string, string>;

	addFile(path: string, value: string) {
		this.fileByPath.set(path, value);
	}

	getFile(path: string) {
		return this.fileByPath.get(path)!;
	}

	private _injectables = new Array<Injectable>;

	get injectables() {
		return Object.freeze([...this._injectables]);
	}

	addInjectable(symbol: GraphSymbol, dependencies: GraphSymbol[]) {
		this._injectables.push({ kind: "injectable", symbol, dependencies });
	}

	private _services = new Array<Service>;

	get services() {
		return Object.freeze([...this._services]);
	}

	addService(symbol: GraphSymbol, dependencies: GraphSymbol[]) {
		this._services.push({ kind: "service", symbol, dependencies });
	}

	private _routes = new Array<Route>;

	get routes() {
		return Object.freeze([...this._routes]);
	}

	addRoute(route: Pick<Route, 'symbol' | 'endpoint' | 'ipc' | 'method'>) {
		this._routes.push({
			kind: "route",
			endpoint: route.endpoint, 
			method: route.method, 
			symbol: route.symbol, 
			ipc: route.ipc
		});
	}

	private _events = new Array<Event>;

	get events() {
		return Object.freeze([...this._events]);
	}

	addEvent(event: Pick<Event, 'symbol' | 'type' | 'once'>) {
		this._events.push({
			kind: "event",
			symbol: event.symbol, 
			type: event.type, 
			once: event.once
		});
	}

	private _commands = new Array<T.File>();

	get commands() {
		return Object.freeze([...this._commands]);
	}

	addCommand(command: T.File) {
		this._commands.push(command);
	}

	private _modules = new Set<Module>();

	get modules(): Readonly<Set<Module>> {
		return this._modules;
	}

	addModule(moduleData: Pick<Module, 'name' | 'managers'>) {
		this._modules.add({ kind: "module", name: moduleData.name, managers: moduleData.managers });
	}
}

export default Graph;

