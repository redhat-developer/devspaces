"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.Sidecar = void 0;
const inversify_1 = require("inversify");
const sidecar_docker_image_1 = require("./sidecar-docker-image");
let Sidecar = class Sidecar {
    isSideCarDirectory(sidecar) {
        return sidecar.directory !== undefined;
    }
    getDockerImageFor(cheTheiaPluginMetaInfo) {
        return __awaiter(this, void 0, void 0, function* () {
            if (!cheTheiaPluginMetaInfo.sidecar) {
                return undefined;
            }
            else if (this.isSideCarDirectory(cheTheiaPluginMetaInfo.sidecar)) {
                return this.sidecarDockerImage.getDockerImageFor(cheTheiaPluginMetaInfo.sidecar.directory);
            }
            else {
                return cheTheiaPluginMetaInfo.sidecar.image;
            }
        });
    }
};
__decorate([
    inversify_1.inject(sidecar_docker_image_1.SidecarDockerImage),
    __metadata("design:type", sidecar_docker_image_1.SidecarDockerImage)
], Sidecar.prototype, "sidecarDockerImage", void 0);
Sidecar = __decorate([
    inversify_1.injectable()
], Sidecar);
exports.Sidecar = Sidecar;
//# sourceMappingURL=sidecar.js.map