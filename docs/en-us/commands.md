---
title: Commands
description: Define slash commands with JSX using Wum + Diseact
---

# Commands

In Wum, commands are declared with JSX and compiled into Discord slash commands.

## Basic command

```tsx
export default (
  <command name="ping" description="Replies with pong">
    {() => <interaction>Pong!</interaction>}
  </command>
)
```

The function child of `<command>` is the handler. Instead of calling `reply` manually, you can return JSX.

## Subcommands

```tsx
export default (
  <command name="user" description="User actions">
    <subcommand name="ban" description="Ban a user">
      <user name="target" description="Target user" />
      {(interaction) => {
        const target = interaction.options.getUser("target", true);
        return <interaction>Banned user: {target.username}</interaction>;
      }}
    </subcommand>

    <subcommand name="info" description="Show info">
      {(interaction) => <interaction>ID: {interaction.user.id}</interaction>}
    </subcommand>
  </command>
)
```

## Subcommand groups

```tsx
export default (
  <command name="admin" description="Admin tools">
    <group name="member" description="Member management">
      <subcommand name="kick" description="Kick member">
        <user name="target" description="User" />
        {() => <interaction>Member kicked.</interaction>}
      </subcommand>
    </group>
  </command>
)
```

## Supported options

You can use options inside `command` and `subcommand`:

- `<string />`
- `<number />`
- `<integer />`
- `<boolean />`
- `<channel />`
- `<user />`
- `<role />`
- `<mentionable />`
- `<attachment />`

Example:

```tsx
export default (
  <command name="echo" description="Repeat text">
    <string name="text" description="Text to repeat" />
    {(interaction) => {
      const text = interaction.options.getString("text", true);
      return <interaction>{text}</interaction>;
    }}
  </command>
)
```

## Useful props

Common command props:

- `name`: command name (required)
- `description`: description (optional, but recommended)
- `ephemeral`: default private response
- `nsfw`: marks command as NSFW
- `localizations`: localized names/descriptions

Option props:

- `name`
- `description`
- `optional` (options are required by default)
- `min` and `max` (strings/numbers)

## Async and hooks

Handlers can be `async`, and components can use Diseact/Wum hooks (`useState`, `useEffect`, `useService`).

For rendering and hooks details, see:

- `rendering.md`
- `hooks.md`
