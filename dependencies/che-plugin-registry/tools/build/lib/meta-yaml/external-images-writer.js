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
exports.ExternalImagesWriter = void 0;
const fs = require("fs-extra");
const path = require("path");
const inversify_1 = require("inversify");
let ExternalImagesWriter = class ExternalImagesWriter {
    write(metaYamlPluginInfos) {
        return __awaiter(this, void 0, void 0, function* () {
            const v3Folder = path.resolve(this.outputRootDirectory, 'v3');
            yield fs.ensureDir(v3Folder);
            const externalImagesFile = path.join(v3Folder, 'external_images.txt');
            const referencedImages = metaYamlPluginInfos
                .map(plugin => {
                const images = [];
                const spec = plugin.spec;
                if (spec) {
                    if (spec.containers) {
                        images.push(...spec.containers.map(container => container.image));
                    }
                    if (spec.initContainers) {
                        images.push(...spec.initContainers.map(initContainer => initContainer.image));
                    }
                }
                return images;
            })
                .reduce((previousValue, currentValue) => previousValue.concat(currentValue), []);
            yield fs.writeFile(externalImagesFile, referencedImages.join('\n'));
        });
    }
};
__decorate([
    inversify_1.inject('string'),
    inversify_1.named('OUTPUT_ROOT_DIRECTORY'),
    __metadata("design:type", String)
], ExternalImagesWriter.prototype, "outputRootDirectory", void 0);
ExternalImagesWriter = __decorate([
    inversify_1.injectable()
], ExternalImagesWriter);
exports.ExternalImagesWriter = ExternalImagesWriter;
//# sourceMappingURL=external-images-writer.js.map