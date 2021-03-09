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
exports.DigestImagesHelper = void 0;
const inversify_1 = require("inversify");
const registry_helper_1 = require("../registry/registry-helper");
let DigestImagesHelper = class DigestImagesHelper {
    updateImages(metaYamlPluginInfos) {
        return __awaiter(this, void 0, void 0, function* () {
            return Promise.all(metaYamlPluginInfos.map((plugin) => __awaiter(this, void 0, void 0, function* () {
                const spec = plugin.spec;
                if (spec) {
                    if (spec.containers) {
                        yield Promise.all(spec.containers.map((container) => __awaiter(this, void 0, void 0, function* () { return (container.image = yield this.registryHelper.getImageDigest(container.image)); })));
                    }
                    if (spec.initContainers) {
                        yield Promise.all(spec.initContainers.map((container) => __awaiter(this, void 0, void 0, function* () { return (container.image = yield this.registryHelper.getImageDigest(container.image)); })));
                    }
                }
                return plugin;
            })));
        });
    }
};
__decorate([
    inversify_1.inject(registry_helper_1.RegistryHelper),
    __metadata("design:type", registry_helper_1.RegistryHelper)
], DigestImagesHelper.prototype, "registryHelper", void 0);
DigestImagesHelper = __decorate([
    inversify_1.injectable()
], DigestImagesHelper);
exports.DigestImagesHelper = DigestImagesHelper;
//# sourceMappingURL=digest-images-helper.js.map