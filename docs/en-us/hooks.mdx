---
title: Hooks
description: State, effects, and service access in Wum
---

# Hooks

Wum re-exports Diseact hooks from `wum.js/hooks` and adds `useService` for DI access.

## useState

`useState` stores local component state and triggers a re-render when the value changes.

```tsx
import { useState } from "wum.js/hooks";

function Counter() {
  const [count, setCount] = useState(0);

  return (
    <interaction>
      <embed>
        <title>Counter</title>
        <description>Count: {count}</description>
      </embed>

      <row>
        <button success label="+" onClick={() => setCount(c => c + 1)} />
      </row>
    </interaction>
  );
}
```

Notes:

- `setCount(newValue)` sets a direct value.
- `setCount(prev => ...)` uses functional updates.
- It only re-renders when the value actually changes.

## useEffect

`useEffect` runs side effects after rendering.

```tsx
import { useEffect, useState } from "wum.js/hooks";

function Timer() {
  const [seconds, setSeconds] = useState(0);

  useEffect(() => {
    const id = setInterval(() => {
      setSeconds(s => s + 1);
    }, 1000);

    return () => clearInterval(id);
  }, []);

  return <interaction>Seconds: {seconds}</interaction>;
}
```

Dependency behavior:

- no array: runs on every render
- `[]`: runs once
- `[a, b]`: runs when any dependency changes

If the callback returns a function, it is used as cleanup before the next execution.

## useService

`useService` is a Wum hook that returns instances managed by the dependency container.

```tsx
import { useService } from "wum.js/hooks";
import { PaymentService } from "../services/payment-service";

function Checkout() {
  const payment = useService(PaymentService);

  return (
    <interaction>
      Status: {payment.isReady() ? "ok" : "loading"}
    </interaction>
  );
}
```

Use it when you need access to singleton services (for example: cache, repository, external provider).

## Best practices

- keep hooks at the top level of the component
- avoid heavy logic directly inside JSX
- encapsulate repeated logic in custom hooks
- prefer `useService` to share application state across commands/components
