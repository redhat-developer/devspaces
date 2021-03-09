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
exports.CheEditorsMetaYamlGenerator = void 0;
const inversify_1 = require("inversify");
const volume_mount_helper_1 = require("../common/volume-mount-helper");
let CheEditorsMetaYamlGenerator = class CheEditorsMetaYamlGenerator {
    compute(cheEditors) {
        return __awaiter(this, void 0, void 0, function* () {
            const metaYamlPluginInfos = yield Promise.all(cheEditors.map((cheEditor) => __awaiter(this, void 0, void 0, function* () {
                const type = 'Che Editor';
                const cheEditorOutput = JSON.stringify(cheEditor);
                const id = cheEditor.id;
                const splitIds = id.split('/');
                if (splitIds.length !== 3) {
                    throw new Error(`The id for ${cheEditorOutput} is not composed of 3 parts separated by / like <1>/<2>/<3>`);
                }
                const publisher = splitIds[0];
                const name = splitIds[1];
                const metaId = `${publisher}/${name}`;
                const version = splitIds[2];
                let disableLatest;
                if (!Number.isInteger(parseInt(version[0]))) {
                    disableLatest = true;
                }
                else {
                    disableLatest = false;
                }
                const displayName = cheEditor.displayName;
                const title = cheEditor.title;
                const description = cheEditor.description;
                const category = 'Editor';
                const iconFile = cheEditor.iconFile;
                const repository = cheEditor.repository;
                const firstPublicationDate = cheEditor.firstPublicationDate;
                const latestUpdateDate = new Date().toISOString().slice(0, 10);
                const spec = {};
                if (cheEditor.endpoints) {
                    spec.endpoints = cheEditor.endpoints;
                }
                if (cheEditor.containers) {
                    spec.containers = cheEditor.containers.map(container => this.volumeMountHelper.resolve(container));
                }
                if (cheEditor.initContainers) {
                    spec.initContainers = cheEditor.initContainers.map(container => this.volumeMountHelper.resolve(container));
                }
                return {
                    id: metaId,
                    disableLatest,
                    publisher,
                    name,
                    version,
                    type,
                    displayName,
                    title,
                    description,
                    iconFile,
                    repository,
                    category,
                    firstPublicationDate,
                    latestUpdateDate,
                    spec,
                };
            })));
            return metaYamlPluginInfos;
        });
    }
};
__decorate([
    inversify_1.inject(volume_mount_helper_1.VolumeMountHelper),
    __metadata("design:type", volume_mount_helper_1.VolumeMountHelper)
], CheEditorsMetaYamlGenerator.prototype, "volumeMountHelper", void 0);
CheEditorsMetaYamlGenerator = __decorate([
    inversify_1.injectable()
], CheEditorsMetaYamlGenerator);
exports.CheEditorsMetaYamlGenerator = CheEditorsMetaYamlGenerator;
//# sourceMappingURL=che-editors-meta-yaml-generator.js.map