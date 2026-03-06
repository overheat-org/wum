import { Client } from "discord.js";

@service
export class InitService {
  constructor(private client: Client) {}

  @event
  OnceReady() {
    console.log(`[pokebot] logged in as ${this.client.user?.tag}`);
  }
}
