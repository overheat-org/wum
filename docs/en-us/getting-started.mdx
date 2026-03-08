---
title: Getting Started
description: Set up and run your first bot with Wum
---

# Getting Started

This guide creates a basic Discord bot with Wum, JSX commands, and services.

## 1. Create a project

```bash
npm init -y
npm i wum.js discord.js
```

## 2. Configure TypeScript

Create a `tsconfig.json` with Wum JSX settings:

```json
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "jsx": "preserve",
    "jsxImportSource": "wum.js",
    "strict": false
  },
  "include": ["src/**/*"]
}
```

## 3. Folder structure

Default structure used by the compiler:

```txt
src/
  commands/**/*.tsx
  services/**/*.{ts,tsx}
```

## 4. First command

Create `src/commands/ping.tsx`:

```tsx
export default (
  <command name="ping" description="Replies with pong">
    {() => <interaction>Pong!</interaction>}
  </command>
)
```

## 5. First service

Create `src/services/init-service.ts`:

```ts
import { Client } from "discord.js";

@service
export class InitService {
  constructor(private client: Client) {}

  @event
  OnceReady() {
    console.log(`Bot online: ${this.client.user?.tag}`);
  }
}
```

## 6. Configure environment

Set these environment variables:

- `TOKEN` (required)
- `GUILD_ID` (optional, to register commands in a specific guild)

Example `.env`:

```env
TOKEN=your_token_here
GUILD_ID=123456789012345678
```

## 7. Build and run

Run the Wum CLI:

```bash
npx wum
```

The build output is generated in `.wum/`, and the runtime bootstraps `WumClient` automatically.

## Optional config

You can create `wum.config.js` to customize paths:

```js
/** @type {import('wum').Config} */
export default {
  entryPath: "src",
  commandsPath: "commands/**/*.tsx",
  servicesPath: "services/**/*.{ts,tsx}",
  buildPath: ".wum"
};
```
