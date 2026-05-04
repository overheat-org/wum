import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { SourceFile } from "./scanner";

export interface SnapshotEntry {
  id: string;
  content: string;
}

export interface CompilerSnapshot {
  virtual_modules: SnapshotEntry[];
  files: SnapshotEntry[];
}

export class ZigAdapter {
  private instancePromise?: Promise<WebAssembly.Instance>;

  constructor(
    private packageRoot = path.dirname(fileURLToPath(import.meta.url)),
  ) {}

  async prepare(files: SourceFile[]): Promise<CompilerSnapshot> {
    const instance = await this.loadInstance();
    const exports = instance.exports as WasmExports;

    const input = JSON.stringify({ files });
    const encoder = new TextEncoder();
    const decoder = new TextDecoder();
    const bytes = encoder.encode(input);

    const inputPtr = exports.wum_alloc(bytes.length);
    if (!inputPtr) throw new Error("Failed to allocate wasm input buffer");

    const memory = new Uint8Array(exports.memory.buffer);
    memory.set(bytes, inputPtr);

    const status = exports.wum_prepare(inputPtr, bytes.length);
    exports.wum_free(inputPtr, bytes.length);

    if (status !== 1) {
      const errorPtr = exports.wum_error_ptr();
      const errorLen = exports.wum_error_len();
      const errorBytes = new Uint8Array(exports.memory.buffer, errorPtr, errorLen);
      throw new Error(decoder.decode(errorBytes));
    }

    const resultPtr = exports.wum_result_ptr();
    const resultLen = exports.wum_result_len();
    const resultBytes = new Uint8Array(exports.memory.buffer, resultPtr, resultLen);

    return JSON.parse(decoder.decode(resultBytes)) as CompilerSnapshot;
  }

  private async loadInstance() {
    this.instancePromise ??= (async () => {
      const wasmPath = await resolveWasmPath(this.packageRoot);
      const wasm = await fs.readFile(wasmPath);
      const { instance } = await WebAssembly.instantiate(wasm, {});
      return instance;
    })();

    return this.instancePromise;
  }
}

interface WasmExports extends WebAssembly.Exports {
  memory: WebAssembly.Memory;
  wum_alloc(length: number): number;
  wum_free(ptr: number, length: number): void;
  wum_prepare(ptr: number, length: number): number;
  wum_result_ptr(): number;
  wum_result_len(): number;
  wum_error_ptr(): number;
  wum_error_len(): number;
}

async function resolveWasmPath(packageRoot: string) {
  const candidates = [
    path.join(packageRoot, "lib", "compiler.wasm"),
    path.join(packageRoot, "zig-out", "lib", "compiler.wasm"),
  ];

  for (const candidate of candidates) {
    try {
      await fs.access(candidate);
      return candidate;
    } catch {}
  }

  throw new Error("compiler.wasm was not found. Run the package build first.");
}
