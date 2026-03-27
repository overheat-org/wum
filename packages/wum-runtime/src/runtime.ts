import { join as j } from "node:path";
import Manifest from "./manifest";
import CommandManager from "./command";
import EventManager from "./event";
import type { WumClient } from "wum.js";
import DependencyManager from "./di/manager";
import { Logger } from "@wumjs/shared";
import ProtocolsManager from "./protocols";

declare const VERSION: string

export class Runtime {
	constructor(client: WumClient, private entryUrl: string) {
		Logger.startup(typeof VERSION === 'undefined' ? 'dev' : VERSION);

		this.dependencyManager = new DependencyManager(client);
		this.protocolManager = new ProtocolsManager(this.dependencyManager);
		this.commandManager = new CommandManager(client);
		this.eventManager = new EventManager(client, this.dependencyManager, this.commandManager);
	}
	
	private commandManager: CommandManager;
	private dependencyManager: DependencyManager;
	private eventManager: EventManager;
	private protocolManager: ProtocolsManager;

	async start() {
		const manifest = await Manifest.parse(j(this.entryUrl, 'manifest.js'));
		
		this.eventManager.setup();
		await this.dependencyManager.load(manifest.dependencies ?? []);
		
		await Promise.all([
			this.commandManager.load(this.entryUrl),
			this.protocolManager.load(manifest.routes ?? []),
			this.eventManager.load(manifest.events ?? [])
		]);
	}
}
