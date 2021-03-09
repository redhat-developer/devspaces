"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.VolumeMountHelper = void 0;
const inversify_1 = require("inversify");
let VolumeMountHelper = class VolumeMountHelper {
    resolve(container) {
        if (container.volumeMounts) {
            container.volumes = container.volumeMounts.map(volumeMount => {
                const volume = { name: volumeMount.name, mountPath: volumeMount.path };
                if (volumeMount.ephemeral) {
                    volume.ephemeral = volumeMount.ephemeral;
                }
                return volume;
            });
            delete container.volumeMounts;
        }
        return container;
    }
};
VolumeMountHelper = __decorate([
    inversify_1.injectable()
], VolumeMountHelper);
exports.VolumeMountHelper = VolumeMountHelper;
//# sourceMappingURL=volume-mount-helper.js.map