import traverse from "@babel/traverse";

export default (traverse as unknown as { default: typeof traverse }).default;