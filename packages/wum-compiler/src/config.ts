import * as vite from "vite";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export interface Config {
  entryPath: string;
  buildPath: string;
  commandsPath: string;
  servicesPath: string;
  cwd: string;
  modules: string[];
  vite: vite.UserConfig;
}

export interface UserConfig extends Partial<Config> {}

const CONFIG_REGEX = /^\.wumrc(\.json)?$|^wum\.config\.(j|t)s(on)?$/;

export async function resolveConfig(cwd: string): Promise<Config> {
  const configPath = await findConfigPath(cwd);
  const data = configPath ? await fs.readFile(configPath, "utf-8") : "{}";
  const unresolved = await parseConfigData(configPath ?? ".wumrc", data);
  return evaluateConfig({
    cwd,
    entryPath: "src",
    buildPath: ".wum",
    commandsPath: "commands/**/*.tsx",
    servicesPath: "services/**/*.{ts,tsx}",
    modules: [],
    vite: {},
    ...unresolved,
  });
}

async function findConfigPath(cwd: string) {
  if (cwd.startsWith("file:")) cwd = fileURLToPath(cwd);

  const files = await fs.readdir(cwd).catch(() => []);
  const fileName = files.find((entry) => CONFIG_REGEX.test(entry));
  if (!fileName) return null;
  return path.join(cwd, fileName);
}

async function parseConfigData(configPath: string, data: string): Promise<UserConfig> {
  if (/\.(j|t)s$/.test(configPath)) {
    const mod = await import(pathToFileURL(configPath).href);
    return { ...(mod.default ?? {}) } satisfies UserConfig;
  }

  if (/\.json|\.\w+rc$/.test(configPath)) {
    return JSON.parse(data) as UserConfig;
  }

  throw new Error("Config extension not recognized");
}

function evaluateConfig(config: Config): Config {
  config.vite ??= {};
  config.vite.base = "./";
  if (config.vite.esbuild === false) {
    config.vite.esbuild = {};
  }
  const esbuild = (config.vite.esbuild ??= {}) as vite.ESBuildOptions;
  esbuild.jsx = "automatic";
  esbuild.jsxImportSource ??= "wum";
  config.vite.build ??= {};
  config.vite.build.outDir = path.join(config.cwd, config.buildPath);

  const rollup = (config.vite.build.rollupOptions ??= {});

  if (rollup.input && !Array.isArray(rollup.input) && typeof rollup.input === "object") {
    throw new Error("Rollup input as object is not supported");
  }

  const input = Array.isArray(rollup.input)
    ? [...rollup.input]
    : typeof rollup.input === "string"
      ? [rollup.input]
      : [];

  input.push("virtual:index", "virtual:commands.tsx", "virtual:manifest");
  rollup.input = input;
  rollup.preserveEntrySignatures = "allow-extension";

  rollup.external = (id) => {
    if (id.startsWith("\0")) return false;
    if (id.startsWith("virtual:")) return false;
    if (id.startsWith("./") || id.startsWith("../")) return false;

    if (path.isAbsolute(id)) {
      const relativeToCwd = path.relative(config.cwd, id);
      const isInsideCwd = !relativeToCwd.startsWith("..") && !path.isAbsolute(relativeToCwd);
      return !isInsideCwd;
    }

    return true;
  };

  if (Array.isArray(rollup.output)) {
    throw new Error("Rollup output as array is not supported");
  }
  const output = (rollup.output ??= {}) as vite.Rollup.OutputOptions & { virtualDirname?: string };

  output.preserveModules = true;
  output.format = "esm";
  output.virtualDirname = output.dir;
  output.entryFileNames = (chunk) => {
    const moduleId = chunk.facadeModuleId ?? "";
    const patternRoot = path.join(config.entryPath, config.servicesPath.split("*")[0] ?? "");

    if (moduleId.startsWith("virtual:")) {
      return `${moduleId.split(":")[1]!.replace(/\.[^.]+$/, "")}.js`;
    }

    if (moduleId.startsWith(path.join(config.cwd, patternRoot))) {
      return `managers/${path.basename(moduleId)}.js`;
    }

    return "[name].js";
  };

  return config;
}
