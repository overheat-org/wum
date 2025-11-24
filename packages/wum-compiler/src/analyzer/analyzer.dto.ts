import * as T from '@babel/types';
import { NodePath } from "@babel/traverse";

export interface DecoratorSchema {
	name: string;
	class?: true;
	method?: true;
	children?: DecoratorSchema;
}

export enum DecoratorType {
	Class,
	Method,
}

interface ClassMacroDecorator {
	type: DecoratorType.Class;
	target: NodePath<T.ClassDeclaration>;
	schema: DecoratorSchema;
	params: T.Node[];
	decorator: NodePath<T.Decorator>
}
interface MethodMacroDecorator {
	type: DecoratorType.Method;
	target: NodePath<T.ClassMethod>;
	schema: DecoratorSchema;
	params: T.Node[];
	decorator: NodePath<T.Decorator>
}

export type MacroDecorator<T extends DecoratorType = any> = T extends DecoratorType.Class
	? ClassMacroDecorator
	: T extends MethodMacroDecorator
		? MethodMacroDecorator
		: ClassMacroDecorator | MethodMacroDecorator;

export enum InstructionKind {
	MacroDecorator,
}

export type AnalyzerInstruction<K, V> = { kind: K, value: V }