import * as vite from "vite";
import BridgePlugin from "./plugin";
import { resolveConfig, type Config } from "./config";
import { ZigAdapter, type CompilerSnapshot } from "./adapter";
import { ProjectScanner } from "./scanner";

class Compiler {
  private adapter = new ZigAdapter();
  private scanner = new ProjectScanner();

  async prepare(cwd = process.cwd()): Promise<{ config: Config; snapshot: CompilerSnapshot }> {
    const config = await resolveConfig(cwd);
    const files = await this.scanner.scanRootModule(cwd, config);
    const snapshot = await this.adapter.prepare(files);

    return { config, snapshot };
  }

  async build(cwd = process.cwd()) {
    const { config, snapshot } = await this.prepare(cwd);
    (config.vite.plugins ??= []).unshift(BridgePlugin(snapshot));
    await vite.build(config.vite);
  }
}

export { BridgePlugin, ZigAdapter };
export type { Config, CompilerSnapshot };
export default Compiler;
