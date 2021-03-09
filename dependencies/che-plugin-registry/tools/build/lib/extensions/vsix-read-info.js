"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
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
exports.VsixReadInfo = void 0;
const fs = require("fs-extra");
const path = require("path");
const inversify_1 = require("inversify");
let VsixReadInfo = class VsixReadInfo {
    read(vsixInfo) {
        return __awaiter(this, void 0, void 0, function* () {
            if (!vsixInfo.unpackedArchive) {
                throw new Error("Cannot read something in unpacked vsix as it's not unpacked.");
            }
            if (!vsixInfo.unpackedExtensionRootDir) {
                throw new Error("Cannot read something in unpacked vsix as it's not unpacked correctly.");
            }
            const packageJsonPath = path.resolve(vsixInfo.unpackedExtensionRootDir, 'package.json');
            const exists = yield fs.pathExists(packageJsonPath);
            if (!exists) {
                throw new Error(`Unable to find package.json file from vsix ${vsixInfo.uri}`);
            }
            const content = yield fs.readFile(packageJsonPath, 'utf-8');
            vsixInfo.packageJson = JSON.parse(content);
            if (vsixInfo.unpackedArchive.endsWith('.vsix')) {
                const packageNlsJsonPath = path.resolve(vsixInfo.unpackedArchive, 'extension', 'package.nls.json');
                const existsNlsFile = yield fs.pathExists(packageNlsJsonPath);
                if (existsNlsFile) {
                    const contentNls = yield fs.readFile(packageNlsJsonPath, 'utf-8');
                    vsixInfo.packageNlsJson = JSON.parse(contentNls);
                }
            }
        });
    }
};
VsixReadInfo = __decorate([
    inversify_1.injectable()
], VsixReadInfo);
exports.VsixReadInfo = VsixReadInfo;
//# sourceMappingURL=vsix-read-info.js.map