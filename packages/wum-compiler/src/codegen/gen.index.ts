class IndexGenerator {
	generate() {
		return `
			import { WumClient } from 'wum.js';

			process.env = {
				...process.env,
			}

			const client = new WumClient({
				entryUrl: import.meta.url,
			});

			client.start();
		`
	}
}

export default IndexGenerator;