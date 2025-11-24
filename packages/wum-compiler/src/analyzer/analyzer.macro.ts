import { WumError } from "@wum/shared";
import Graph from "../graph";
import { DependencyAnalyzer } from "./analyzer.dependency";
import { DecoratorType, MacroDecorator } from "./analyzer.dto";

class MacroAnalyzer {
	async analyze(ctx: MacroDecorator) {
		const map = {
			injectable: this.analyzeInjectable,
			service: this.analyzeService,
			http: this.analyzeHttp,
			event: this.analyzeEvent
		}

		map[ctx.schema.name as keyof typeof map](ctx as any);
	}

	async analyzeInjectable(ctx: MacroDecorator<DecoratorType.Class>) {
		const dependencies = await this.dependencyAnalyzer.analyzeClass(ctx.target);
		const symbol = this.graph.resolveSymbol(ctx.decorator);
		this.graph.addInjectable(symbol, dependencies);
	}

	async analyzeService(ctx: MacroDecorator<DecoratorType.Class>) {
		const dependencies = await this.dependencyAnalyzer.analyzeClass(ctx.target);
		const symbol = this.graph.resolveSymbol(ctx.decorator);
		this.graph.addService(symbol, dependencies);
	}

	analyzeHttp(ctx: MacroDecorator<DecoratorType.Method>) {
		const [routeParam] = ctx.params;

		if(!routeParam) throw "";
		if (!routeParam.isStringLiteral()) throw "";

		const endpoint = routeParam.node.value;

		const classNode = ctx.target.findParent(p => p.isClassDeclaration()) as NodePath<T.ClassDeclaration>;
		const symbol = this.graph.resolveSymbol(ctx.target, classNode);

		this.graph.addRoute({
			endpoint,
			method,
			symbol,
			ipc: false
		});
	}

	analyzeEvent(ctx: MacroDecorator<DecoratorType.Method>) {
		const classNode = ctx.target.findParent(p => p.isClassDeclaration()) as NodePath<T.ClassDeclaration>;
		const symbol = this.graph.resolveSymbol(ctx.target, classNode);

		const key = ctx.target.get('key');
		if (!key.isIdentifier()) {
			const locStart = key.node.loc?.start!;

			throw new WumError("Expected a comptime known class method name", ctx.decorator);
		};

		const methodName = key.node.name;

		const NAME_ERROR = new WumError(
			"The method name should starts with 'On' or 'Once' and continue with a discord event name\n\nlike: 'OnceReady'",
			ctx.decorator
		);

		const matches = methodName.match(/^(On|Once)([A-Z][a-zA-Z]*)$/);
		if (!matches) throw NAME_ERROR;

		const once = { Once: true, On: false }[matches[1]];
		if (once === undefined) throw NAME_ERROR;

		const type = matches[2].charAt(0).toLowerCase() + matches[2].slice(1);

		this.graph.addEvent({
			once,
			type,
			symbol
		});
	}

	constructor(private dependencyAnalyzer: DependencyAnalyzer, private graph: Graph) { }
}

export default MacroAnalyzer;