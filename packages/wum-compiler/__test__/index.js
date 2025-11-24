import { describe, it, mock } from 'node:test';
import { Scanner, Transformer } from '../';

describe('Scanner.scanRootModule', () => {
	it('scaneia comandos e serviços', async () => {
		const fakeConfig = {
			entryPath: '',
			vite: { plugins: [] }
		};

		mock.method(fs, 'glob', async function* () {
			yield 'command/ping.tsx';
			yield 'service/logger.ts';
		});

		mock.method(fs, 'readFile', async () => 'conteudo');

		const scanner = new Scanner();

		mock.method(scanner['configManager'], 'resolve', async () => fakeConfig);

		const commandSpy = mock.method(
			scanner['transformer'],
			'transformCommand',
			async () => { }
		);

		const serviceSpy = mock.method(
			scanner['transformer'],
			'transformService',
			async () => { }
		);

		await scanner.scanRootModule(process.cwd());

		assert.equal(fakeConfig.vite.plugins[0].name, "@wum/compiler");

		mock.method(Transformer.prototype, 'transformService', async (...args) => {
			
			
			return Transformer.prototype.transformService(...args);
		});
	});
});
