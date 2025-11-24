import fs from 'fs';
import { dirname, basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export class ImportResolver {
	async resolve(spec: string, fromFile: string): Promise<ResolvedImport> {
		if (spec.startsWith(".")) {
			const file = await this.resolveRelative(spec, fromFile);
			return { kind: "file", path: file };
		}

		const entry = await this.resolvePackageEntry(spec);
		const root = await this.findPackageRoot(entry);

		return { kind: "module", root, entry };
	}

	private async resolveRelative(spec: string, fromFile: string) {
		const baseDir = dirname(fromFile);
		let target = join(baseDir, spec);

		// resolver extensão baseada na pasta
		if (!/\.\w+$/.test(target)) {
			target = await this.resolveExtension(target);
		}

		return target;
	}

	private async resolveExtension(path: string) {
		const dir = dirname(path);
		const name = basename(path);
		const files = await fs.promises.readdir(dir);

		const match = files.find(
			f => f === name || f.startsWith(name + ".")
		);

		if (!match) throw new Error("Unknown file");

		return join(dir, match);
	}

	private async resolvePackageEntry(spec: string) {
		const url = import.meta.resolve(spec);
		return fileURLToPath(url);
	}

	private async findPackageRoot(file: string): Promise<string> {
		let dir = dirname(file);

		while (true) {
			const files = await fs.promises.readdir(dir).catch(() => new Array<string>);

			if (files.includes("package.json")) return dir;

			const parent = dirname(dir);
			if (parent === dir) break;

			dir = parent;
		}

		throw new Error("Package root not found");
	}
}

// tipos auxiliares
export type ResolvedImport =
	| { kind: "file", path: string }
	| { kind: "module", root: string, entry: string };