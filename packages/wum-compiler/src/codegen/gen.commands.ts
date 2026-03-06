import * as T from "@babel/types";
import Graph from "../graph";

class CommandsGenerator {
	constructor(private graph: Graph) {}

	get(index: number) {
		const command = this.graph.commands[index];
		if (!command) {
			throw new Error(`Command at index ${index} was not found`);
		}
		return command;
	}
	
	generate() {
		const { commands } = this.graph;
		const body: T.Statement[] = [];
		const container = T.identifier("__container__");

		body.push(T.importDeclaration(
			[T.importSpecifier(container, T.identifier("CommandContainer"))],
			T.stringLiteral("wum.js")
		));

		for (const command of commands) {
			const stmt = command.node.body[0];
			if (!T.isExportDefaultDeclaration(stmt)) {
				throw new Error("Expected command to start with export default");
			}
			if (!T.isFunctionExpression(stmt.declaration)) {
				throw new Error("Expected export default function in command");
			}
			body.push(T.expressionStatement(
				T.callExpression(
					T.memberExpression(container, T.identifier("add")),
					[stmt.declaration]
				)
			));
		}

		body.push(T.exportDefaultDeclaration(container));

		return T.program(body);
	}
}

export default CommandsGenerator;
