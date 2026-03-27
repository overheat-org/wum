import { Events } from "discord.js";
import DependencyManager from "./di/manager";
import CommandManager from "./command";
import { ClassLike } from "./di/resolver";
import { Logger } from "@wumjs/shared";
import type { WumClient } from "wum.js";

export interface Event {
    type: any,
    once?: boolean,
    handler: string,
    entity: ClassLike
}

class EventManager {
	constructor(
		private client: WumClient, 
		private dependencyManager: DependencyManager, 
		private commandManager: CommandManager
	) {}

    async load(events: Event[] = []) {
		events.forEach(this.loadEvent.bind(this));
    }

    setup() {
        this.client.on(Events.InteractionCreate, interaction => {
            if (interaction.isChatInputCommand() || interaction.isAutocomplete()) {
                void this.commandManager.run(interaction);
            }
        });

        this.client.once(Events.ClientReady, () => {
			Logger.ready(this.client.user?.tag ?? "unknown");
			void Promise.resolve(this.commandManager.register()).catch((error: Error) => {
                Logger.error(error.message ?? "Failed to register commands");
            });
		});
    }

    private loadEvent(event: Event) {
        const instance = this.dependencyManager.getInstanceFrom(event.entity);
        if(!instance) {
            throw new Error("Use @event in classes marked with injectable or manager.")
        }
        const handler = (instance as any)[event.handler];
        if (typeof handler !== "function") {
            throw new Error(`Event handler '${event.handler}' was not found on ${event.entity.name}`);
        }

        this.client[event.once ? 'once' : 'on'](event.type, handler.bind(instance));
    }
}

export default EventManager;
