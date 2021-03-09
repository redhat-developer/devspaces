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
exports.VsixDownload = void 0;
const fs = require("fs-extra");
const path = require("path");
const url = require("url");
const inversify_1 = require("inversify");
const axios_1 = require("axios");
let VsixDownload = class VsixDownload {
    download(vsixInfo) {
        return __awaiter(this, void 0, void 0, function* () {
            const vsixUri = vsixInfo.uri;
            const link = url.parse(vsixUri);
            if (!link.pathname) {
                throw new Error('invalid link URI: ' + vsixUri);
            }
            const dirname = path.dirname(link.pathname);
            const basename = path.basename(link.pathname);
            const filename = dirname.replace(/\W/g, '_') + '-' + basename;
            const unpackedPath = path.resolve(this.downloadRootDirectory, path.basename(filename));
            const pathExists = yield fs.pathExists(unpackedPath);
            vsixInfo.downloadedArchive = unpackedPath;
            if (pathExists) {
                return;
            }
            const writer = fs.createWriteStream(unpackedPath);
            const response = yield axios_1.default.get(vsixUri, { responseType: 'stream' });
            response.data.pipe(writer);
            return new Promise((resolve, reject) => {
                writer.on('finish', () => resolve());
                writer.on('error', error => reject(error));
            });
        });
    }
};
__decorate([
    inversify_1.inject('string'),
    inversify_1.named('DOWNLOAD_ROOT_DIRECTORY'),
    __metadata("design:type", String)
], VsixDownload.prototype, "downloadRootDirectory", void 0);
VsixDownload = __decorate([
    inversify_1.injectable()
], VsixDownload);
exports.VsixDownload = VsixDownload;
//# sourceMappingURL=vsix-download.js.map