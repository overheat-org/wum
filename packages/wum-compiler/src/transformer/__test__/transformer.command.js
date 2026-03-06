import { describe, it } from 'node:test';
import assert from 'node:assert';
import Graph from '../../graph';
import Parser from '../../parser';
import { CommandTransformer } from '../transformer.command';

describe("transform command", () => {
	it("should rewrite imports and default export into async function", () => {
		const graph = new Graph();
		const parser = new Parser(graph);
		const transformer = new CommandTransformer();
		const filename = "/repo/src/commands/ping.tsx";

		const ast = parser.parse(filename, `
			import PingSvc, { PongSvc } from "../managers/ping";
			export default <command name="ping"></command>;
		`);

		transformer.transform(ast);

		assert.equal(ast.node.body.length, 1);
		const [onlyStatement] = ast.node.body;
		assert.equal(onlyStatement.type, "ExportDefaultDeclaration");
		assert.equal(onlyStatement.declaration.type, "FunctionExpression");
		assert.equal(onlyStatement.declaration.async, true);

		const fnBody = onlyStatement.declaration.body.body;
		assert.equal(fnBody.length, 3);
		assert.equal(fnBody[0].type, "VariableDeclaration");
		assert.equal(fnBody[1].type, "VariableDeclaration");
		assert.equal(fnBody[2].type, "ReturnStatement");

		const initDefault = fnBody[0].declarations[0].init;
		assert.equal(initDefault.type, "MemberExpression");
		assert.equal(initDefault.object.type, "AwaitExpression");
		assert.equal(initDefault.object.argument.type, "CallExpression");
		assert.equal(initDefault.object.argument.callee.type, "Import");
		assert.equal(
			initDefault.object.argument.arguments[0].value,
			"/repo/src/services/ping"
		);
		assert.equal(initDefault.property.type, "Identifier");
		assert.equal(initDefault.property.name, "default");

		const initNamed = fnBody[1].declarations[0].init;
		assert.equal(initNamed.type, "MemberExpression");
		assert.equal(
			initNamed.object.argument.arguments[0].value,
			"/repo/src/services/ping"
		);
		assert.equal(initNamed.property.type, "Identifier");
		assert.equal(initNamed.property.name, "PongSvc");
	});
});
