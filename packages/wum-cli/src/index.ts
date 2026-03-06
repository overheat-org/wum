import inspector from 'node:inspector';

const flags = {
	"--inspect": {
		description: "Enable inspector mode",
		async has(port = 9229) {
			inspector.open(port, "127.0.0.1", true);
		}
	}
}

async function main() {
	for(const arg of process.argv) {
		const [argName, argValue] = arg.split("=");

		await flags[argName as keyof typeof flags]?.has(
			argValue
				? JSON.parse(argValue)
				: undefined,
		);
	}
	
	const { default: Compiler } = await import("@wum/compiler"); 
	
	const compiler = new Compiler();
	
	await compiler.build();
}

main();