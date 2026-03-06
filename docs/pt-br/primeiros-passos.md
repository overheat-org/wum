---
title: Primeiros Passos
description: Configure e rode seu primeiro bot com Wum
---

# Primeiros Passos

Este guia cria um bot Discord basico com Wum, comandos JSX e servicos.

## 1. Criar projeto

```bash
npm init -y
npm i wum.js discord.js
```

## 2. Configurar TypeScript

Crie um `tsconfig.json` com JSX do Wum:

```json
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "jsx": "preserve",
    "jsxImportSource": "wum",
    "strict": false
  },
  "include": ["src/**/*"]
}
```

## 3. Estrutura de pastas

Estrutura padrao lida pelo compilador:

```txt
src/
  commands/**/*.tsx
  services/**/*.{ts,tsx}
```

## 4. Primeiro comando

Crie `src/commands/ping.tsx`:

```tsx
export default (
  <command name="ping" description="Responde pong">
    {() => <interaction>Pong!</interaction>}
  </command>
)
```

## 5. Primeiro servico

Crie `src/services/init-service.ts`:

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

## 6. Configurar ambiente

Defina as variaveis:

- `TOKEN` (obrigatoria)
- `GUILD_ID` (opcional, para registrar comandos em uma guild especifica)

Exemplo `.env`:

```env
TOKEN=seu_token_aqui
GUILD_ID=123456789012345678
```

## 7. Compilar e rodar

Rode o CLI do Wum:

```bash
npx wum
```

O build e gerado em `.wum/` e o runtime inicializa o `WumClient` automaticamente.

## Configuracao opcional

Voce pode criar `wum.config.js` para customizar caminhos:

```js
/** @type {import('wum').Config} */
export default {
  entryPath: "src",
  commandsPath: "commands/**/*.tsx",
  servicesPath: "services/**/*.{ts,tsx}",
  buildPath: ".wum"
};
```
