import fs from "node:fs/promises";
import path from "node:path";
import type { Config } from "./config";

export type SourceFileKind = "command" | "service";

export interface SourceFile {
  path: string;
  source: string;
  kind: SourceFileKind;
}

export class ProjectScanner {
  private readCache = new Map<string, string>();
  private scanCache = new Set<string>();
  private configCache = new Map<string, Config>();
  private packageNameCache = new Map<string, string | null>();

  async scanRootModule(cwd: string, config: Config): Promise<SourceFile[]> {
    const basePath = path.join(cwd, config.entryPath);
    const files: SourceFile[] = [];

    this.configCache.set(path.resolve(cwd), config);

    await this.scanPattern(path.join(basePath, config.commandsPath), "command", config, files);
    await this.scanPattern(path.join(basePath, config.servicesPath), "service", config, files);

    for (const modulePath of config.modules) {
      const resolved = path.isAbsolute(modulePath) ? modulePath : path.join(cwd, modulePath);
      const moduleFiles = await this.scanModule(resolved);
      files.push(...moduleFiles);
    }

    return files;
  }

  async scanModule(cwd: string): Promise<SourceFile[]> {
    const { resolveConfig } = await import("./config");
    const resolvedCwd = path.resolve(cwd);
    const config = this.configCache.get(resolvedCwd) ?? await resolveConfig(resolvedCwd);
    this.configCache.set(resolvedCwd, config);
    const basePath = path.join(cwd, config.entryPath);
    const files: SourceFile[] = [];

    await this.scanPattern(path.join(basePath, config.commandsPath), "command", config, files);
    await this.scanPattern(path.join(basePath, config.servicesPath), "service", config, files);
    return files;
  }

  async scanFile(filePath: string, kind: SourceFileKind, config: Config, out?: SourceFile[]) {
    const absolutePath = path.resolve(filePath);
    if (this.scanCache.has(absolutePath)) return out ?? [];

    this.scanCache.add(absolutePath);
    const target = out ?? [];
    const source = await this.readFile(absolutePath);
    target.push({
      path: absolutePath,
      source,
      kind,
    });

    await this.scanImports(absolutePath, source, config, target);
    return target;
  }

  private async scanPattern(pattern: string, kind: SourceFileKind, config: Config, out: SourceFile[]) {
    const entries = await globFiles(pattern);
    for (const entry of entries) {
      await this.scanFile(entry, kind, config, out);
    }
  }

  private async readFile(filePath: string) {
    const cached = this.readCache.get(filePath);
    if (cached) return cached;

    const source = await fs.readFile(filePath, "utf-8");
    this.readCache.set(filePath, source);
    return source;
  }

  private async scanImports(filePath: string, source: string, config: Config, out: SourceFile[]) {
    for (const rawImport of extractImportSources(source)) {
      const resolved = await this.resolveImport(rawImport, filePath, config);
      if (!resolved) continue;

      if (resolved.kind === "file") {
        await this.scanFile(resolved.path, resolved.fileKind, config, out);
        continue;
      }

      const moduleFiles = await this.scanModule(resolved.root);
      out.push(...moduleFiles);
    }
  }

  private async resolveImport(source: string, fromFile: string, config: Config): Promise<ResolvedImport | null> {
    if (source.startsWith("./") || source.startsWith("../") || source.startsWith("/")) {
      const resolvedFile = await resolveScriptImport(source, fromFile);
      if (!resolvedFile) return null;

      return {
        kind: "file",
        path: resolvedFile,
        fileKind: inferFileKind(config, resolvedFile),
      };
    }

    for (const modulePath of config.modules) {
      const root = path.resolve(config.cwd, modulePath);
      const packageName = await this.readPackageName(root);
      if (!packageName) continue;
      if (!matchesModuleImport(source, packageName)) continue;
      return { kind: "module", root };
    }

    return null;
  }

  private async readPackageName(moduleRoot: string) {
    if (this.packageNameCache.has(moduleRoot)) {
      return this.packageNameCache.get(moduleRoot) ?? null;
    }

    const packageJsonPath = path.join(moduleRoot, "package.json");
    try {
      const content = await fs.readFile(packageJsonPath, "utf-8");
      const pkg = JSON.parse(content) as { name?: string };
      const packageName = typeof pkg.name === "string" ? pkg.name : null;
      this.packageNameCache.set(moduleRoot, packageName);
      return packageName;
    } catch {
      this.packageNameCache.set(moduleRoot, null);
      return null;
    }
  }
}

type ResolvedImport =
  | { kind: "file"; path: string; fileKind: SourceFileKind }
  | { kind: "module"; root: string };

function isScriptFile(filePath: string) {
  return /\.(t|j)sx?$/.test(filePath);
}

function inferFileKind(config: Config, filePath: string): SourceFileKind {
  const commandRoot = path.join(config.cwd, config.entryPath, normalizePatternRoot(config.commandsPath));
  if (isInside(path.resolve(commandRoot), filePath)) return "command";
  return "service";
}

function normalizePatternRoot(pattern: string) {
  return (pattern.split("*")[0] ?? "").replace(/\/+$/, "");
}

function isInside(rootPath: string, filePath: string) {
  const relative = path.relative(rootPath, filePath);
  return relative !== "" && !relative.startsWith("..") && !path.isAbsolute(relative);
}

function extractImportSources(source: string) {
  const imports = new Set<string>();
  const patterns = [
    /\bimport\s+(?:type\s+)?(?:[\s\S]*?\s+from\s+)?["']([^"']+)["']/g,
    /\bexport\s+\*\s+from\s+["']([^"']+)["']/g,
    /\bexport\s+\{[\s\S]*?\}\s+from\s+["']([^"']+)["']/g,
  ];

  for (const pattern of patterns) {
    for (const match of source.matchAll(pattern)) {
      const importSource = match[1];
      if (importSource) imports.add(importSource);
    }
  }

  return [...imports];
}

async function resolveScriptImport(source: string, fromFile: string) {
  const basePath = source.startsWith("/")
    ? source
    : path.resolve(path.dirname(fromFile), source);

  const candidates = [
    basePath,
    `${basePath}.ts`,
    `${basePath}.tsx`,
    `${basePath}.js`,
    `${basePath}.jsx`,
    path.join(basePath, "index.ts"),
    path.join(basePath, "index.tsx"),
    path.join(basePath, "index.js"),
    path.join(basePath, "index.jsx"),
  ];

  for (const candidate of candidates) {
    if (!isScriptFile(candidate)) continue;
    if (await exists(candidate)) return path.resolve(candidate);
  }

  return null;
}

function matchesModuleImport(source: string, packageName: string) {
  return source === packageName || source.startsWith(`${packageName}/`);
}

async function exists(filePath: string) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function walk(rootPath: string): Promise<string[]> {
  const result: string[] = [];
  const stack = [rootPath];

  while (stack.length > 0) {
    const current = stack.pop()!;
    const entries = await fs.readdir(current, { withFileTypes: true });

    for (const entry of entries) {
      const absolute = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(absolute);
      } else if (entry.isFile()) {
        result.push(absolute);
      }
    }
  }

  return result;
}

async function globFiles(pattern: string): Promise<string[]> {
  const glob = (fs as typeof fs & { glob?: (pattern: string) => AsyncIterable<string> }).glob;
  if (typeof glob === "function") {
    const entries: string[] = [];
    for await (const entry of glob(pattern)) {
      if (isScriptFile(entry)) entries.push(path.resolve(entry));
    }
    return entries;
  }

  const rootPath = patternRoot(pattern);
  if (!(await exists(rootPath))) return [];
  const entries = await walk(rootPath);
  return entries.filter((entry) => isScriptFile(entry) && matchesGlob(pattern, entry));
}

function patternRoot(pattern: string) {
  const globIndex = pattern.search(/[*{[]/);
  return (globIndex === -1 ? pattern : pattern.slice(0, globIndex)).replace(/\/+$/, "");
}

function matchesGlob(pattern: string, filePath: string) {
  if (typeof (path as typeof path & { matchesGlob?: (path: string, pattern: string) => boolean }).matchesGlob === "function") {
    return (path as typeof path & { matchesGlob: (path: string, pattern: string) => boolean }).matchesGlob(filePath, pattern);
  }

  const normalizedPattern = normalizeGlob(pattern);
  const normalizedPath = filePath.split(path.sep).join("/");
  const regex = new RegExp(`^${normalizedPattern}$`);
  return regex.test(normalizedPath);
}

function normalizeGlob(pattern: string) {
  const normalized = pattern.split(path.sep).join("/");
  return normalized
    .replace(/[.+^${}()|[\]\\]/g, "\\$&")
    .replace(/\\\*\\\*/g, ".*")
    .replace(/\\\*/g, "[^/]*")
    .replace(/\\\{([^}]+)\\\}/g, (_, group: string) => `(${group.split(",").map((part) => part.replace(/\./g, "\\.")).join("|")})`);
}
