import * as T from "@babel/types";
import Graph from "../graph";

class CommandsGenerator {
	constructor(private graph: Graph) {}
	
	generate() {
		const { commands } = this.graph;
		
		let body = Array<T.Statement>(commands.length + 2);
		
		const i = T.identifier("__container__");
		
		body.push(T.importDeclaration(
			[T.importSpecifier(i, T.identifier("CommandContainer"))],
			T.stringLiteral("wum.js")
		));
		
		for(const command of commands) {
			const node = command.program.body[0];
			if(node.type != "ExpressionStatement") throw new Error("Expected ExpressionStatement");

			const callExpr = node.expression;
			if(callExpr.type != "CallExpression") throw new Error("Expected CallExpression");
	 	
			body.push(T.expressionStatement(
				T.callExpression(
					T.memberExpression(
						i,
						T.identifier("add")
					),
					[
						callExpr.callee as T.FunctionExpression
					]
				)
			))
			
		}

		body.push(T.exportDefaultDeclaration(i));
		
		return T.program(body);
	}
}

export default CommandsGenerator;