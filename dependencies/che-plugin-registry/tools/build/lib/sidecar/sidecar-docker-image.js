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
var SidecarDockerImage_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.SidecarDockerImage = void 0;
const path = require("path");
const inversify_1 = require("inversify");
const simple_git_1 = require("simple-git");
let SidecarDockerImage = SidecarDockerImage_1 = class SidecarDockerImage {
    constructor() {
        this.git = simple_git_1.default({ maxConcurrentProcesses: 1 });
    }
    init() {
        return __awaiter(this, void 0, void 0, function* () {
            this.gitRootDirectory = yield this.git.revparse(['--show-toplevel']);
        });
    }
    getDockerImageFor(sidecarShortDirectory) {
        return __awaiter(this, void 0, void 0, function* () {
            const format = {
                hash: '%H',
            };
            const fullPathSideCarDirectory = path.resolve(this.gitRootDirectory, 'sidecars', sidecarShortDirectory);
            const logOptions = {
                format,
                file: fullPathSideCarDirectory,
                n: '1',
            };
            const result = yield this.git.log(logOptions);
            const latest = result.latest;
            if (!latest) {
                throw new Error(`Unable to find result when executing ${JSON.stringify(logOptions)}`);
            }
            const hash = latest.hash;
            return `${SidecarDockerImage_1.PREFIX_IMAGE}:${sidecarShortDirectory}-${hash.substring(0, 7)}`;
        });
    }
};
SidecarDockerImage.PREFIX_IMAGE = 'quay.io/eclipse/che-plugin-sidecar';
__decorate([
    inversify_1.postConstruct(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], SidecarDockerImage.prototype, "init", null);
SidecarDockerImage = SidecarDockerImage_1 = __decorate([
    inversify_1.injectable(),
    __metadata("design:paramtypes", [])
], SidecarDockerImage);
exports.SidecarDockerImage = SidecarDockerImage;
//# sourceMappingURL=sidecar-docker-image.js.map