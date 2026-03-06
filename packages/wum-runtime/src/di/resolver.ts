import { Client } from "discord.js";

export type ClassLike = new (...args: any[]) => any;
type Injectable = {
    entity?: ClassLike;
    service?: ClassLike;
    dependencies?: ClassLike[];
    managers?: ClassLike[];
};

// TODO: Make it analyze each dependency at the same time without forward bugs
export class DependencyInjectorResolver {
    private processingStack = new Set<ClassLike>();
    public instanceFromDependency = new Map<ClassLike, any>();
    private dependenciesFromEntity = new Map<ClassLike, ClassLike[]>();
    private unresolvedDependencies = new Set<ClassLike>();

    constructor(client: Client) {
        this.instanceFromDependency.set(Client, client);
        this.instanceFromDependency.set(client.constructor as ClassLike, client);
    }

    register(entity: ClassLike, dependencies: ClassLike[] = []) {
        if (!this.dependenciesFromEntity.has(entity)) {
            this.dependenciesFromEntity.set(entity, dependencies);
            this.unresolvedDependencies.add(entity);
        }
    }

    addLooseDependency(dependency: ClassLike) {
        if (!this.instanceFromDependency.has(dependency) && !this.dependenciesFromEntity.has(dependency)) {
            this.unresolvedDependencies.add(dependency);
        }
    }

    async resolve(): Promise<void> {
        for (const dep of Array.from(this.unresolvedDependencies)) {
            await this.resolveDependency(dep);
        }
    }

    async parseGraph(graph: Injectable[] = []) {
        graph.forEach((item) => {
            const dependencyList = item.dependencies?.filter((dep): dep is ClassLike => typeof dep === "function") ?? [];
            const entity = item.entity ?? item.service;
            if (typeof entity === "function") {
                this.register(entity, dependencyList);
            }

            const managers = item.managers?.filter((manager): manager is ClassLike => typeof manager === "function") ?? [];
            managers.forEach(manager => this.register(manager));
        });
    }

    // private defineForward(entity: ClassLike): () => any {
    //     const ref = { current: undefined };
    //     const forwardFn = () => ref.current;
    //     forwardFn[FORWARD_SYMBOL] = true;
    //     this.instanceFromDependency.set(entity, ref);
    //     return forwardFn;
    // }

    private async resolveDependency(entity: ClassLike): Promise<any> {
        if (this.instanceFromDependency.has(entity)) {
            const value = this.instanceFromDependency.get(entity);
            return typeof value === "object" && "current" in value ? value.current : value;
        }

        if (this.processingStack.has(entity)) {
            throw new Error(`cycle detected at: ${entity.name}`)
        }

        this.processingStack.add(entity);
        try {
            const deps = this.dependenciesFromEntity.get(entity) || [];
            const params = await Promise.all(deps.map(d => this.resolveDependency(d)));
            const instance = new entity(...params);

            const existing = this.instanceFromDependency.get(entity);
            if (typeof existing === "object" && existing && "current" in existing) {
                existing.current = instance;
            } else {
                this.instanceFromDependency.set(entity, instance);
            }

            this.unresolvedDependencies.delete(entity);
            return instance;
        } finally {
            this.processingStack.delete(entity);
        }
    }

    [Symbol.dispose]() {
        this.processingStack.clear();
        this.dependenciesFromEntity.clear();
        this.instanceFromDependency.clear();
        this.unresolvedDependencies.clear();
    }
}
