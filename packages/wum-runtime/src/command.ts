// import { InteractionExecutor } from "diseact";
import { extname } from "node:path";
import { AutocompleteInteraction, ChatInputCommandInteraction, Guild } from "discord.js";
import { WumClient, CommandContainer } from "wum.js";

class CommandManager {
	constructor(private client: WumClient) {}
	
    // private executor = new InteractionExecutor();
    private container?: CommandContainer;

    async load(entryPath: string) {
        const commandFilePath = extname(entryPath) === ".js"
            ? entryPath
            : `${entryPath}/commands.js`;
        const { default: container }: { default: CommandContainer } = await import(commandFilePath);

        // this.executor.commandMap = container.map;
        this.container = container;
    }

    async register() {
        if(!this.container) {
            throw new Error('CommandManager cannot register without load before');
        }

        const guild: Guild | undefined = process.env.GUILD_ID
            ? this.client.guilds.cache.get(process.env.GUILD_ID)
            : undefined;

        if (guild) {
            await guild.commands.set(this.container.list);
        } else {
            await this.client.application!.commands.set(this.container.list);
        }
    }

    async run(interaction: ChatInputCommandInteraction | AutocompleteInteraction) {
        // this.executor.run(interaction);
    }
}

export default CommandManager;
