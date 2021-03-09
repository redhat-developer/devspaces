"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.commonModule = void 0;
const inversify_1 = require("inversify");
const volume_mount_helper_1 = require("./volume-mount-helper");
const commonModule = new inversify_1.ContainerModule((bind) => {
    bind(volume_mount_helper_1.VolumeMountHelper).toSelf().inSingletonScope();
});
exports.commonModule = commonModule;
//# sourceMappingURL=common-module.js.map