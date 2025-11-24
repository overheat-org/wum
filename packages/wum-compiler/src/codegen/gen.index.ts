class IndexGenerator {
	generate() {
		return `
			import { WumClient } from 'wum';

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