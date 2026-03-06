---
title: Renderizacao
description: Como o Wum (via Diseact) renderiza comandos, componentes e atualizacoes
---

# Renderizacao

O Wum usa o Diseact para transformar JSX em payloads do Discord e controlar o ciclo de renderizacao.

## Como funciona

1. Seu componente/comando retorna JSX (`<message>`, `<interaction>`, `<embed>`, etc).
2. O JSX e transformado em objetos do Discord (embeds, componentes, opcoes de comando).
3. O Diseact envia a primeira resposta.
4. Quando estado muda (`useState`), o componente e renderizado novamente e a resposta anterior e editada.

## Primeiro render vs re-render

O comportamento depende do alvo de renderizacao:

- `ChatInputCommandInteraction`
- primeiro render: `interaction.reply(...)`
- re-render: `interaction.editReply(...)`

- `Message`
- primeiro render: `message.channel.send(...)`
- re-render: `message.edit(...)`

- canais/usuarios/membros
- render: `target.send(...)`

## Em comandos Wum

Nos comandos, voce normalmente retorna JSX no handler em vez de chamar `reply` manualmente:

```tsx
export default (
  <command name="ping" description="Retorna pong">
    {() => (
      <interaction>
        Pong!
      </interaction>
    )}
  </command>
)
```

Isso permite usar hooks e re-renderizacao automaticamente.

## Elementos comuns

Elementos mais usados no Wum + Diseact:

- `<interaction>`: resposta de slash command
- `<message>`: estrutura de mensagem
- `<embed>`, `<title>`, `<description>`, `<footer>`, `<author>`
- `<row>`, `<button>`, `<selectmenu>`, `<modal>`, `<textinput>`
- `<command>`, `<subcommand>`, `<group>` para declaracao de comandos

## Exemplo com estado

```tsx
import { useState } from "wum.js/hooks";

function Counter() {
  const [count, setCount] = useState(0);

  return (
    <interaction>
      <embed>
        <title>Contador</title>
        <description>Total: {count}</description>
      </embed>

      <row>
        <button success label="+1" onClick={() => setCount(c => c + 1)} />
      </row>
    </interaction>
  );
}
```

Ao clicar no botao, `setCount` dispara novo render, e o Diseact atualiza a resposta.

## Observacoes praticas

- Para fluxo declarativo, prefira retornar JSX.
- Se o comando precisa de respostas adicionais fora do ciclo de render, voce pode usar a API do `interaction`.
- Componentes funcionais sao o formato ideal para reaproveitar UI e logica.
