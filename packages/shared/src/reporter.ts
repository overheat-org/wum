import type { NodePath } from "@babel/traverse";

export type WumErrorLocation = { path?: string, line?: number, column?: number }

export class WumError extends Error {
	name = "WumError"
	
	constructor(message: string, path?: NodePath) {
		const { loc } = path?.node ?? {};
		const { line, column } = loc?.start ?? {};

		if (loc) message += `\n    at ${loc.filename}:${line}:${column}`;
		super(message);
		Error.captureStackTrace?.(this, WumError);
	}
}