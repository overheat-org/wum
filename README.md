<div align="center">
  <img 
    alt="Wum logo" 
    src="https://raw.githubusercontent.com/overheat-org/wum/main/assets/logo.svg"
    height="200"
  >
  <h1>Wum</h1>
  <p>A framework for building Discord bots with JSX + TypeScript.</p>
</div>

## About

Wum is a productivity-focused framework for Discord bots, with declarative commands, reactive rendering, and a service-based architecture.

## Features

- JSX-first command architecture for defining slash commands and interaction flows in a declarative way.
- Declarative Discord UI rendering powered by Diseact, including messages, embeds, components, and interaction updates.
- Reactive hooks model for local state, side effects, and service access inside command components.
- Macro decorators for services and events, with compile-time analysis of metadata and runtime registration.
- Built-in dependency injection container for clean service composition and low-coupling business logic.
- SQLite-backed persistence utilities for lightweight key-value storage and incremental IDs.
- CLI-driven developer workflow with automatic compile, manifest generation, and bot runtime bootstrap.

## Advantages

- Memory-less command layer: command definitions are compiled into runtime artifacts, reducing dynamic setup and keeping execution lightweight.
- Scalable architecture: services + dependency injection make it easier to split domains, reuse logic, and grow large bots safely.
- Fast iteration cycle: JSX rendering and hooks reduce boilerplate, so new commands and UI flows can be shipped quickly.
- Maintainable codebase: clear separation between commands, services, and infrastructure improves readability and long-term evolution.
- Production-friendly runtime: automated build/runtime flow lowers operational friction and keeps project structure consistent.

## Quick Start

```bash
npm i wum.js discord.js
npx wum
```

Docs:
- PT-BR: `docs/pt-br`
- EN-US: `docs/en-us`

## Community

- Discord: https://discord.gg/null
