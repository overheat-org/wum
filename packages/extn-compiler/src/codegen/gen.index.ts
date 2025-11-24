class IndexGenerator {
	generate() {
		return `
			import { ExtnClient } from 'extn';

			process.env = {
				...process.env,
			}

			const client = new ExtnClient({
				entryUrl: import.meta.url,
			});

			client.start();
		`
	}
}

export default IndexGenerator;