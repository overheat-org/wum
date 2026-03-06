# Pokebot Example

Simple Wum bot with Pokemon slash commands.

## Commands

- `/pokemon info name:<pokemon>`
- `/pokemon random`

## Run

```bash
cd examples/pokebot
npm i
# set TOKEN (and optionally GUILD_ID)
npm run dev
```

If you are developing inside this monorepo and want to use the local CLI build:

```bash
node ../../packages/wum-cli/lib/index.js
```
