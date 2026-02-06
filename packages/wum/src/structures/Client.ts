import { Client, ClientOptions } from "discord.js";
import { dirname } from "node:path";
import Runtime from '@wum/runtime';

export class WumClient extends Client {
	private runtime: Runtime;

    constructor(options: ClientOptions & { entryUrl: string }) {
        super(options);

        const entryUrl = dirname(options.entryUrl);
		this.runtime = new Runtime(this as any, entryUrl);
    }

    public async start(): Promise<string> {
		await this.runtime.start();
        return this.login(process.env.TOKEN!);
    }
}