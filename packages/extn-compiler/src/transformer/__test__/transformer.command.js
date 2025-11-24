import { it, describe } from 'node:test';
import { CommandTransformer } from '../transformer.command';
import Parser from '../../parser';
import CommandAnalyzer from '../../analyzer/analyzer.command';
import assert from 'node:assert';

const UNEXPECTED = new Error("A unexpected ast was encontered");

// describe("transform command", () => {
// 	const parser = new Parser();
// 	const analyzer = new CommandAnalyzer();
// 	const transformer = new CommandTransformer(analyzer);
	
// 	const ast = parser.parse();
// 	transformer.transform(ast);

// 	const [iifeDecl] = ast.program.body;
// 	if(iifeDecl.type != "ExpressionStatement") throw UNEXPECTED;

// 	const callExpr = iifeDecl.expression;
// 	if(callExpr.type != "CallExpression") throw UNEXPECTED;

// 	const fnExpr = callExpr.callee;
// 	if(fnExpr.type != "FunctionExpression") throw UNEXPECTED;

// 	const blockBody = fnExpr.body.body;
// 	const returnStmt = blockBody.find(s => s.type == "ReturnStatement");
// 	if(!returnStmt) throw UNEXPECTED;
// });