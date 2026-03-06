---
title: Hooks
description: Estado, efeitos e acesso a servicos no Wum
---

# Hooks

O Wum reexporta hooks do Diseact em `wum.js/hooks` e adiciona o hook `useService` para DI.

## useState

`useState` guarda estado local do componente e dispara re-render quando o valor muda.

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

Notas:

- `setCount(novoValor)` define valor direto.
- `setCount(prev => ...)` usa atualizacao funcional.
- so re-renderiza quando o valor realmente muda.

## useEffect

`useEffect` executa efeitos colaterais apos renderizar.

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

  return <interaction>Segundos: {seconds}</interaction>;
}
```

Comportamento de dependencias:

- sem array: roda a cada render
- `[]`: roda uma vez
- `[a, b]`: roda quando alguma dependencia muda

Se o callback retornar funcao, ela sera usada como cleanup antes da proxima execucao.

## useService

`useService` e um hook do Wum para recuperar instancias gerenciadas pelo container de dependencias.

```tsx
import { useService } from "wum.js/hooks";
import { PaymentService } from "../services/payment-service";

function Checkout() {
  const payment = useService(PaymentService);

  return (
    <interaction>
      Status: {payment.isReady() ? "ok" : "carregando"}
    </interaction>
  );
}
```

Use quando precisar acessar um servico singleton (ex.: cache, repositorio, integracao externa).

## Boas praticas

- mantenha hooks no topo do componente
- evite logica pesada dentro do JSX
- encapsule logica repetida em hooks customizados
- prefira `useService` para compartilhar estado de aplicacao entre comandos/componentes
