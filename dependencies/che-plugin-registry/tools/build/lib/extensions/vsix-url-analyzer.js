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
exports.VsixUrlAnalyzer = void 0;
const inversify_1 = require("inversify");
const deferred_1 = require("../util/deferred");
const vsix_download_1 = require("./vsix-download");
const vsix_read_info_1 = require("./vsix-read-info");
const vsix_unpack_1 = require("./vsix-unpack");
let VsixUrlAnalyzer = class VsixUrlAnalyzer {
    constructor() {
        this.deferredPromises = new Map();
    }
    analyze(vsixInfo) {
        return __awaiter(this, void 0, void 0, function* () {
            let deferred = this.deferredPromises.get(vsixInfo.uri);
            if (!deferred) {
                deferred = new deferred_1.Deferred();
                this.deferredPromises.set(vsixInfo.uri, deferred);
            }
            else {
                yield deferred.promise;
            }
            yield this.vsixDownload.download(vsixInfo);
            yield this.vsixUnpack.unpack(vsixInfo);
            yield this.vsixReadInfo.read(vsixInfo);
            deferred.resolve();
        });
    }
};
__decorate([
    inversify_1.inject(vsix_download_1.VsixDownload),
    __metadata("design:type", vsix_download_1.VsixDownload)
], VsixUrlAnalyzer.prototype, "vsixDownload", void 0);
__decorate([
    inversify_1.inject(vsix_unpack_1.VsixUnpack),
    __metadata("design:type", vsix_unpack_1.VsixUnpack)
], VsixUrlAnalyzer.prototype, "vsixUnpack", void 0);
__decorate([
    inversify_1.inject(vsix_read_info_1.VsixReadInfo),
    __metadata("design:type", vsix_read_info_1.VsixReadInfo)
], VsixUrlAnalyzer.prototype, "vsixReadInfo", void 0);
VsixUrlAnalyzer = __decorate([
    inversify_1.injectable(),
    __metadata("design:paramtypes", [])
], VsixUrlAnalyzer);
exports.VsixUrlAnalyzer = VsixUrlAnalyzer;
//# sourceMappingURL=vsix-url-analyzer.js.map