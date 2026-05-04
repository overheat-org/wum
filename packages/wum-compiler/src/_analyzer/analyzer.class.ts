import MacroAnalyzer from "./analyzer.macro";
import TypeAnalyzer from "./analyzer.type";

class ClassAnalyzer {
	constructor(
		private macroAnalyzer: MacroAnalyzer,
		private typeAnalyzer: TypeAnalyzer,
	) {}
	
	analyzeMethod() {
		const ctx = this.analyzeThis();

		if(ctx.target == 'storage') return this.analyzeStorageExpr(ctx);
	}

	analyzeThis() {
		
	}

	analyzeStorageExpr(ctx) {
		if(ctx.type == 'CallExpression') {
			const [T] = ctx.typeParameters.params;

			// bind

			const typeDefinition = {} as any;


			ctx.replaceWith(`
				this.storage.__alloc__(obj, {
					guild: "discord.js@Guild"
				})
			`)
		}

	}
}