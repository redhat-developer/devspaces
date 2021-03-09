"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sidecarModule = void 0;
const inversify_1 = require("inversify");
const sidecar_1 = require("./sidecar");
const sidecar_docker_image_1 = require("./sidecar-docker-image");
const sidecarModule = new inversify_1.ContainerModule((bind) => {
    bind(sidecar_1.Sidecar).toSelf().inSingletonScope();
    bind(sidecar_docker_image_1.SidecarDockerImage).toSelf().inSingletonScope();
});
exports.sidecarModule = sidecarModule;
//# sourceMappingURL=plugin-module.js.map