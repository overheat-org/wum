---
title: Services
description: Dependency injection, events, and shared state in Wum
---

# Services

Services are singleton classes loaded by the Wum runtime.

They are ideal for:

- business rules
- database/cache access
- external integrations
- Discord event listeners

## Decorators

Main decorators for services:

- `@service`: registers the class in the DI container
- `@injectable`: registers an injectable helper/infrastructure class
- `@event`: marks a method as a Discord event listener

## Event with `@event`

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

Method naming rules:

- method name must start with `On` or `Once`
- the remaining name maps to the Discord event
- examples: `OnceReady`, `OnMessageCreate`

## Service dependencies

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

Dependencies are resolved by the runtime container.

## Injecting the client

You can receive `Client` (discord.js) in the constructor:

```ts
import { Client } from "discord.js";

@service
export class AuditService {
  constructor(private client: Client) {}
}
```

## Sharing a service in JSX

To use a service inside a component/command, use `useService`:

```tsx
import { useService } from "wum.js/hooks";
import { CheckoutService } from "../services/checkout-service";

function CheckoutView() {
  const checkout = useService(CheckoutService);

  return <interaction>Status: {String(checkout.createOrder())}</interaction>;
}
```

## Persistence with Storage

Wum exposes `Storage` and `autoincrement` for simple SQLite persistence:

```ts
import { Storage, autoincrement } from "wum.js";

const users = new Storage<{ points: number }>("users");

await users.set("user:1", { points: 10 });
const nextOrderId = await autoincrement("orders");
```

Default database path: `./database/data.sqlite`.
