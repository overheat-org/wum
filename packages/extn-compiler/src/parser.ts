import { parse } from '@babel/parser';

class Parser {
	parse(path: string, content: string) {
		const ast = parse(content, {
			sourceType: 'module',
			sourceFilename: path,
			plugins: ["decorators", "typescript", "jsx"],
			errorRecovery: true
		});
		
		return ast;
	}
}

export default Parser;