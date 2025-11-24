import Compiler from "@wum/compiler";

(async () => {
	const compiler = new Compiler();
	
	await compiler.build();
})();