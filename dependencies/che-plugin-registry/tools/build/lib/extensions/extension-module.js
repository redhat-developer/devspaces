"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.extensionsModule = void 0;
const inversify_1 = require("inversify");
const vsix_download_1 = require("./vsix-download");
const vsix_read_info_1 = require("./vsix-read-info");
const vsix_unpack_1 = require("./vsix-unpack");
const vsix_url_analyzer_1 = require("./vsix-url-analyzer");
const extensionsModule = new inversify_1.ContainerModule((bind) => {
    bind(vsix_download_1.VsixDownload).toSelf().inSingletonScope();
    bind(vsix_read_info_1.VsixReadInfo).toSelf().inSingletonScope();
    bind(vsix_unpack_1.VsixUnpack).toSelf().inSingletonScope();
    bind(vsix_url_analyzer_1.VsixUrlAnalyzer).toSelf().inSingletonScope();
});
exports.extensionsModule = extensionsModule;
//# sourceMappingURL=extension-module.js.map