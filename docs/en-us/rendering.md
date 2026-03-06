---
title: Rendering
description: How Wum (through Diseact) renders commands, components, and updates
---

# Rendering

Wum uses Diseact to transform JSX into Discord payloads and manage the rendering lifecycle.

## How it works

1. Your component/command returns JSX (`<message>`, `<interaction>`, `<embed>`, etc).
2. JSX is transformed into Discord objects (embeds, components, command options).
3. Diseact sends the first response.
4. When state changes (`useState`), the component re-renders and updates the previous response.

## First render vs re-render

Behavior depends on the render target:

- `ChatInputCommandInteraction`
- first render: `interaction.reply(...)`
- re-render: `interaction.editReply(...)`

- `Message`
- first render: `message.channel.send(...)`
- re-render: `message.edit(...)`

- channels/users/members
- render: `target.send(...)`

## In Wum commands

In commands, you usually return JSX from the handler instead of calling `reply` manually:

```tsx
export default (
  <command name="ping" description="Returns pong">
    {() => (
      <interaction>
        Pong!
      </interaction>
    )}
  </command>
)
```

This enables automatic hooks and re-rendering.

## Common elements

Most common Wum + Diseact elements:

- `<interaction>`: slash command response
- `<message>`: message structure
- `<embed>`, `<title>`, `<description>`, `<footer>`, `<author>`
- `<row>`, `<button>`, `<selectmenu>`, `<modal>`, `<textinput>`
- `<command>`, `<subcommand>`, `<group>` for command declaration

## Stateful example

```tsx
import { useState } from "wum.js/hooks";

function Counter() {
  const [count, setCount] = useState(0);

  return (
    <interaction>
      <embed>
        <title>Counter</title>
        <description>Total: {count}</description>
      </embed>

      <row>
        <button success label="+1" onClick={() => setCount(c => c + 1)} />
      </row>
    </interaction>
  );
}
```

When the button is clicked, `setCount` triggers a new render and Diseact updates the response.

## Practical notes

- For declarative flow, prefer returning JSX.
- If a command needs extra responses outside the render cycle, you can still use the interaction API.
- Functional components are the best format to reuse UI and logic.
