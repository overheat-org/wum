import { describe, it } from 'node:test';
import assert from 'node:assert';
import Parser from '../../parser';
import CommandAnalyzer from '../analyzer.command';

describe("analyze command", () => {
	const parser = new Parser();
	const analyzer = new CommandAnalyzer();

	const shouldReject = [
		{
			name: "named export",
			code: `
				export const a = 5;
				export default <command></command>;
			`,
			error: /Cannot export in command/
		},
		{
			name: "enum declaration",
			code: `
				enum RandomEnum { A, B }
				export default <command></command>;
			`,
			error: /Cannot use enum in command/
		},
		{
			name: "class declaration",
			code: `
				class A {}
				export default <command></command>;
			`,
			error: /Cannot use class in command/
		},
		{
			name: "non-command default export",
			code: `export default 5;`,
			error: /Cannot export by default a non-command element/
		}
	];

	const shouldAccept = [
		{
			name: "valid command",
			code: `export default <command></command>`
		}
	];

	for (const { name, code, error } of shouldReject) {
		it(`should reject ${name}`, () => {
			const node = parser.parse("test.tsx", code);

			assert.throws(
				() => analyzer.analyze(node),
				{ name: "WumError", message: error }
			);
		});
	}

	for (const { name, code } of shouldAccept) {
		it(`should accept ${name}`, () => {
			const node = parser.parse("test.tsx", code);

			assert.doesNotThrow(() => analyzer.analyze(node));
		});
	}
});