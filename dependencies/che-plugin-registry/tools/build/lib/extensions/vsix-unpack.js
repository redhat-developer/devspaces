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
exports.VsixUnpack = void 0;
const decompress = require("decompress");
const fs = require("fs-extra");
const path = require("path");
const inversify_1 = require("inversify");
let VsixUnpack = class VsixUnpack {
    updateIconInfo(rootDir, vsixInfo) {
        return __awaiter(this, void 0, void 0, function* () {
            const packageJsonPath = path.resolve(rootDir, 'package.json');
            const statsFile = yield fs.stat(packageJsonPath);
            vsixInfo.creationDate = statsFile.mtime.toISOString().slice(0, 10);
        });
    }
    unpack(vsixInfo) {
        return __awaiter(this, void 0, void 0, function* () {
            if (!vsixInfo.downloadedArchive) {
                throw new Error('Cannot unpack a vsix as it is not yet downloaded.');
            }
            const destFolder = path.resolve(this.unpackedRootDirectory, path.basename(vsixInfo.uri));
            vsixInfo.unpackedArchive = destFolder;
            let rootDir;
            if (vsixInfo.uri.endsWith('.vsix')) {
                rootDir = path.resolve(destFolder, 'extension');
            }
            else if (vsixInfo.uri.endsWith('.theia')) {
                rootDir = path.resolve(destFolder);
            }
            else {
                throw new Error(`Unknown URI format for uri ${vsixInfo.uri}`);
            }
            vsixInfo.unpackedExtensionRootDir = rootDir;
            const pathExists = yield fs.pathExists(destFolder);
            if (pathExists) {
                this.updateIconInfo(rootDir, vsixInfo);
                return;
            }
            yield decompress(vsixInfo.downloadedArchive, destFolder);
            this.updateIconInfo(rootDir, vsixInfo);
        });
    }
};
__decorate([
    inversify_1.inject('string'),
    inversify_1.named('UNPACKED_ROOT_DIRECTORY'),
    __metadata("design:type", String)
], VsixUnpack.prototype, "unpackedRootDirectory", void 0);
VsixUnpack = __decorate([
    inversify_1.injectable()
], VsixUnpack);
exports.VsixUnpack = VsixUnpack;
//# sourceMappingURL=vsix-unpack.js.map