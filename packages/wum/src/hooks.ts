import { DependencyBridge } from '@wum/runtime';

export * from 'diseact/hooks';

export function useService<S extends new (...args: any[]) => any>(service: S) {
	return DependencyBridge.request(service);
}