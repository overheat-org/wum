import { IPCManager } from "./ipc";
import { HTTPManager } from "./http";
import { ClassLike } from "../di/resolver";
import DependencyManager from "../di/manager";

export interface Endpoint {
    endpoint: string,
    method: string,
    handler: string,
    entity: ClassLike,
    ipc?: boolean
}

class ProtocolsManager {
    constructor(private dependencyManager: DependencyManager) {}

    ipcManager = new IPCManager();
    httpManager = new HTTPManager();

    async load(routes: Endpoint[] = []) {
        const ipc: Endpoint[] = [];
        const http: Endpoint[] = [];
        routes.forEach((route) => {
            if (route.ipc) {
                ipc.push(route);
                return;
            }

            http.push(route);
        });

		this.loadEndpoints(ipc, this.ipcManager);
		this.loadEndpoints(http, this.httpManager);
    }

    loadEndpoints(endpoints: Endpoint[], manager: IPCManager | HTTPManager) {
        endpoints.forEach(e => {
            const instance = this.dependencyManager.getInstanceFrom(e.entity);
            if (!instance) {
                throw new Error(`Missing dependency instance for route entity: ${e.entity.name}`);
            }

            const handler = (instance as any)[e.handler];
            if (typeof handler !== "function") {
                throw new Error(`Route handler '${e.handler}' was not found on ${e.entity.name}`);
            }

            const method = e.method.toLowerCase();
            const register = (manager as any)[method];
            if (typeof register !== "function") {
                throw new Error(`Unsupported protocol method '${e.method}' for endpoint '${e.endpoint}'`);
            }

            register.call(manager, e.endpoint, handler.bind(instance));
        });
    }
}

export default ProtocolsManager;
