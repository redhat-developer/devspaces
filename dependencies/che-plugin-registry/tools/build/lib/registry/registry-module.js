"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.registryModule = void 0;
const inversify_1 = require("inversify");
const registry_helper_1 = require("./registry-helper");
const registryModule = new inversify_1.ContainerModule((bind) => {
    bind(registry_helper_1.RegistryHelper).toSelf().inSingletonScope();
});
exports.registryModule = registryModule;
//# sourceMappingURL=registry-module.js.map