import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { ProjectScanner } from "../scanner.ts";

test("scanner follows relative imports from scanned files", async () => {
  const cwd = await fs.mkdtemp(path.join(os.tmpdir(), "wum-scanner-"));

  await fs.mkdir(path.join(cwd, "src", "commands"), { recursive: true });
  await fs.mkdir(path.join(cwd, "src", "services"), { recursive: true });

  await fs.writeFile(
    path.join(cwd, "src", "commands", "ping.tsx"),
    'import { Repo } from "../services/repo";\nexport default <command name="ping"></command>;\n',
  );
  await fs.writeFile(
    path.join(cwd, "src", "services", "repo.ts"),
    "export class Repo {}\n",
  );

  const scanner = new ProjectScanner();
  const files = await scanner.scanRootModule(cwd, {
    cwd,
    entryPath: "src",
    buildPath: ".wum",
    commandsPath: "commands/**/*.tsx",
    servicesPath: "services/**/*.{ts,tsx}",
    modules: [],
    vite: {},
  });

  const ids = new Set(files.map((file) => path.relative(cwd, file.path)));
  assert.ok(ids.has(path.join("src", "commands", "ping.tsx")));
  assert.ok(ids.has(path.join("src", "services", "repo.ts")));
});

test("scanner follows configured module imports by package name", async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "wum-scanner-module-"));
  const appCwd = path.join(root, "app");
  const moduleCwd = path.join(root, "feature-module");

  await fs.mkdir(path.join(appCwd, "src", "services"), { recursive: true });
  await fs.mkdir(path.join(moduleCwd, "src", "services"), { recursive: true });

  await fs.writeFile(
    path.join(appCwd, "src", "services", "app.ts"),
    'import { FeatureService } from "@wum/feature";\nexport class App {}\n',
  );
  await fs.writeFile(
    path.join(moduleCwd, "package.json"),
    JSON.stringify({ name: "@wum/feature" }),
  );
  await fs.writeFile(
    path.join(moduleCwd, ".wumrc"),
    JSON.stringify({ entryPath: "src" }),
  );
  await fs.writeFile(
    path.join(moduleCwd, "src", "services", "feature.ts"),
    "export class FeatureService {}\n",
  );

  const scanner = new ProjectScanner();
  const files = await scanner.scanRootModule(appCwd, {
    cwd: appCwd,
    entryPath: "src",
    buildPath: ".wum",
    commandsPath: "commands/**/*.tsx",
    servicesPath: "services/**/*.{ts,tsx}",
    modules: [path.relative(appCwd, moduleCwd)],
    vite: {},
  });

  const ids = new Set(files.map((file) => path.relative(root, file.path)));
  assert.ok(ids.has(path.join("app", "src", "services", "app.ts")));
  assert.ok(ids.has(path.join("feature-module", "src", "services", "feature.ts")));
});
