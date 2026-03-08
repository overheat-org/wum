---
title: Servicos
description: Injeção de dependencias, eventos e estado compartilhado no Wum
---

# Servicos

Servicos sao classes singleton carregadas pelo runtime do Wum.

Eles sao ideais para:

- regra de negocio
- acesso a banco/cache
- integracoes externas
- listeners de eventos Discord

## Decorators

Decorators principais para servicos:

- `@service`: registra classe no container de DI
- `@injectable`: registra classe injetavel (auxiliar/infra)
- `@event`: marca metodo como listener de evento Discord

## Evento com `@event`

```ts
import { Client } from "discord.js";

@service
export class ReadyService {
  constructor(private client: Client) {}

  @event
  OnceReady() {
    console.log(`Online: ${this.client.user?.tag}`);
  }
}
```

Regra de nome do metodo:

- deve comecar com `On` ou `Once`
- o restante vira o nome do evento do Discord
- exemplos: `OnceReady`, `OnMessageCreate`

## Dependencias entre servicos

```ts
@injectable
export class PaymentGateway {
  charge() {
    return true;
  }
}

@service
export class CheckoutService {
  constructor(private gateway: PaymentGateway) {}

  createOrder() {
    return this.gateway.charge();
  }
}
```

As dependencias sao resolvidas pelo container do runtime.

## Injetando o cliente

Voce pode receber `Client` (discord.js) no construtor:

```ts
import { Client } from "discord.js";

@service
export class AuditService {
  constructor(private client: Client) {}
}
```

## Compartilhar servico no JSX

Para usar um servico dentro de componente/comando, use `useService`:

```tsx
import { useService } from "wum.js/hooks";
import { CheckoutService } from "../services/checkout-service";

function CheckoutView() {
  const checkout = useService(CheckoutService);

  return <interaction>Status: {String(checkout.createOrder())}</interaction>;
}
```

## Persistencia com Storage

Wum expoe `Storage` e `autoincrement` para persistencia simples em SQLite:

```ts
import { Storage, autoincrement } from "wum.js";

const users = new Storage<{ points: number }>("users");

await users.set("user:1", { points: 10 });
const nextOrderId = await autoincrement("orders");
```

Banco padrao: `./database/data.sqlite`.
