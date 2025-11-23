import * as T from '@babel/types';
import { NodePath } from '@babel/traverse';
import { ExtnError } from '@extn/shared';
import { ImportAnalyzer } from './analyzer.import';

export class DependencyAnalyzer {	
	constructor(private importAnalyzer: ImportAnalyzer) {}

	async analyzeClass(path: NodePath<T.ClassDeclaration>) {
		const classBody = path.get('body').get('body');
		const constructor = classBody.find(m => m.isClassMethod() && m.node.kind === "constructor");

		if (!constructor) {
			return [];
		}

		return await this.analyzeConstructor(constructor as NodePath<T.ClassMethod>);
	}

	private analyzeConstructor(path: NodePath<T.ClassMethod>) {
		const params = path.get('params');

		return Promise.all(params.map(p => {
			if (!p.isTSParameterProperty()) {
				throw new ExtnError("This parameter cannot be injectable", path);
			}

			return this.analyzeParameter(p);
		}));
	}

	private analyzeParameter(path: NodePath<T.TSParameterProperty>) {
		const parameter = path.get("parameter");
		const typeAnnotation = parameter.get("typeAnnotation");

		if (!typeAnnotation.isTSTypeAnnotation()) {
			throw new ExtnError("Expected a type annotation for injectable parameter", path);
		}

		const typeRef = typeAnnotation.get("typeAnnotation");

		if (!typeRef.isTSTypeReference()) {
			throw new ExtnError("Expected a injectable type reference", path);
		}

		return this.importAnalyzer.analyzeTypeDeclaration(typeRef);
	}
}