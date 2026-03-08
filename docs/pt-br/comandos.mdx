---
title: Comandos
description: Defina slash commands com JSX usando Wum + Diseact
---

# Comandos

No Wum, comandos sao declarados com JSX e compilados para slash commands do Discord.

## Comando basico

```tsx
export default (
  <command name="ping" description="Responde pong">
    {() => <interaction>Pong!</interaction>}
  </command>
)
```

A funcao filha do `<command>` e o handler. Em vez de `reply` manual, voce pode retornar JSX.

## Subcomandos

```tsx
export default (
  <command name="user" description="Acoes de usuario">
    <subcommand name="ban" description="Bane um usuario">
      <user name="target" description="Usuario alvo" />
      {(interaction) => {
        const target = interaction.options.getUser("target", true);
        return <interaction>Usuario banido: {target.username}</interaction>;
      }}
    </subcommand>

    <subcommand name="info" description="Mostra informacoes">
      {(interaction) => <interaction>ID: {interaction.user.id}</interaction>}
    </subcommand>
  </command>
)
```

## Grupos de subcomando

```tsx
export default (
  <command name="admin" description="Ferramentas administrativas">
    <group name="member" description="Gestao de membros">
      <subcommand name="kick" description="Expulsa membro">
        <user name="target" description="Usuario" />
        {() => <interaction>Membro expulso.</interaction>}
      </subcommand>
    </group>
  </command>
)
```

## Opcoes suportadas

Voce pode usar opcoes dentro de `command` e `subcommand`:

- `<string />`
- `<number />`
- `<integer />`
- `<boolean />`
- `<channel />`
- `<user />`
- `<role />`
- `<mentionable />`
- `<attachment />`

Exemplo:

```tsx
export default (
  <command name="echo" description="Repete texto">
    <string name="texto" description="Texto para repetir" />
    {(interaction) => {
      const texto = interaction.options.getString("texto", true);
      return <interaction>{texto}</interaction>;
    }}
  </command>
)
```

## Props uteis

Props comuns em comandos:

- `name`: nome do comando (obrigatorio)
- `description`: descricao (opcional, mas recomendado)
- `ephemeral`: resposta padrao privada
- `nsfw`: marca comando como NSFW
- `localizations`: localizacao de nome/descricao

Props de opcoes:

- `name`
- `description`
- `optional` (por padrao, opcao e obrigatoria)
- `min` e `max` (strings/numeros)

## Async e hooks

Handlers podem ser `async` e componentes podem usar hooks do Diseact/Wum (`useState`, `useEffect`, `useService`).

Para detalhes de ciclo de renderizacao e hooks, veja:

- `renderizacao.md`
- `hooks.md`
