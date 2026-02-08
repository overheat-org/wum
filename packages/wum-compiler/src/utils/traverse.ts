import traverse from "@babel/traverse";

const resolved = (traverse as unknown as { default?: typeof traverse }).default ?? traverse;

export default resolved;
