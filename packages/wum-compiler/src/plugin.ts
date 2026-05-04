import type { Plugin } from "vite";
import type { CompilerSnapshot } from "./adapter";

declare const __NAME__: string;
declare const __VERSION__: string;

export function BridgePlugin(snapshot: CompilerSnapshot): Plugin {
  const virtuals = new Map(snapshot.virtual_modules.map((entry) => [entry.id, entry.content]));
  const files = new Map(snapshot.files.map((entry) => [entry.id, entry.content]));

  return {
    name: __NAME__,
    version: __VERSION__,
    resolveId(id) {
      if (virtuals.has(id)) return id;
      if (files.has(id)) return id;
      return null;
    },
    load(id) {
      if (virtuals.has(id)) return virtuals.get(id)!;
      if (files.has(id)) return files.get(id)!;
      return null;
    },
  };
}

export default BridgePlugin;
