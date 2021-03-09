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
exports.RegistryHelper = void 0;
const crypto = require("crypto");
const inversify_1 = require("inversify");
const simple_git_1 = require("simple-git");
const axios_1 = require("axios");
const docker_image_name_parser_1 = require("docker-image-name-parser");
let RegistryHelper = class RegistryHelper {
    constructor() {
        this.git = simple_git_1.default({ maxConcurrentProcesses: 1 });
    }
    init() {
        return __awaiter(this, void 0, void 0, function* () {
            const gitRootDirectory = yield this.git.revparse(['--show-toplevel']);
            const logOptions = {
                format: { hash: '%H' },
                file: gitRootDirectory,
                n: '1',
            };
            const result = yield this.git.log(logOptions);
            const hash = result.latest.hash;
            this.shortSha1 = hash.substring(0, 7);
        });
    }
    getImageDigest(imageName) {
        return __awaiter(this, void 0, void 0, function* () {
            if (imageName.startsWith('docker.io')) {
                imageName = imageName.replace('docker.io', 'index.docker.io');
            }
            const dockerImageName = docker_image_name_parser_1.parse(imageName);
            if (dockerImageName.tag === 'nightly' || dockerImageName.tag === 'next') {
                return imageName;
            }
            if (dockerImageName.tag && dockerImageName.tag.includes(this.shortSha1)) {
                console.log(`Do not fetch digest for ${imageName} as the tag ${dockerImageName.tag} includes the current sha1 ${this.shortSha1}`);
                return imageName;
            }
            const uri = `https://${dockerImageName.host}/v2/${dockerImageName.remoteName}/manifests/${dockerImageName.tag}`;
            let token;
            if (dockerImageName.host === 'index.docker.io') {
                const tokenUri = `https://auth.docker.io/token?service=registry.docker.io&scope=repository:${dockerImageName.remoteName}:pull`;
                const tokenResponse = yield axios_1.default.get(tokenUri, {
                    headers: {
                        Accept: 'application/vnd.docker.distribution.manifest.v2+json,application/vnd.docker.distribution.manifest.list.v2+json',
                    },
                    responseType: 'json',
                });
                token = tokenResponse.data.token;
            }
            const headers = {};
            if (token) {
                headers['Authorization'] = `Bearer ${token}`;
            }
            headers['Accept'] =
                'application/vnd.docker.distribution.manifest.v2+json,application/vnd.docker.distribution.manifest.list.v2+json';
            const response = yield axios_1.default.get(uri, {
                headers,
                responseType: 'arraybuffer',
            });
            const content = Buffer.from(response.data, 'binary').toString();
            const hash = crypto.createHash('sha256').update(content).digest('hex');
            const verifyUri = `https://${dockerImageName.host}/v2/${dockerImageName.remoteName}/manifests/sha256:${hash}`;
            yield axios_1.default.head(verifyUri, {
                headers,
                responseType: 'arraybuffer',
            });
            return `${dockerImageName.host}/${dockerImageName.remoteName}@sha256:${hash}`;
        });
    }
};
__decorate([
    inversify_1.postConstruct(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], RegistryHelper.prototype, "init", null);
RegistryHelper = __decorate([
    inversify_1.injectable(),
    __metadata("design:paramtypes", [])
], RegistryHelper);
exports.RegistryHelper = RegistryHelper;
//# sourceMappingURL=registry-helper.js.map