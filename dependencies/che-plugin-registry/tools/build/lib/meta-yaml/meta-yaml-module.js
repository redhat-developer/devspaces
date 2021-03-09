"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.metaYamlModule = void 0;
const inversify_1 = require("inversify");
const digest_images_helper_1 = require("./digest-images-helper");
const external_images_writer_1 = require("./external-images-writer");
const index_writer_1 = require("./index-writer");
const meta_yaml_writer_1 = require("./meta-yaml-writer");
const metaYamlModule = new inversify_1.ContainerModule((bind) => {
    bind(digest_images_helper_1.DigestImagesHelper).toSelf().inSingletonScope();
    bind(external_images_writer_1.ExternalImagesWriter).toSelf().inSingletonScope();
    bind(index_writer_1.IndexWriter).toSelf().inSingletonScope();
    bind(meta_yaml_writer_1.MetaYamlWriter).toSelf().inSingletonScope();
});
exports.metaYamlModule = metaYamlModule;
//# sourceMappingURL=meta-yaml-module.js.map