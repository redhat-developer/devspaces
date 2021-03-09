"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.editorModule = void 0;
const inversify_1 = require("inversify");
const che_editors_analyzer_1 = require("./che-editors-analyzer");
const che_editors_meta_yaml_generator_1 = require("./che-editors-meta-yaml-generator");
const editorModule = new inversify_1.ContainerModule((bind) => {
    bind(che_editors_analyzer_1.CheEditorsAnalyzer).toSelf().inSingletonScope();
    bind(che_editors_meta_yaml_generator_1.CheEditorsMetaYamlGenerator).toSelf().inSingletonScope();
});
exports.editorModule = editorModule;
//# sourceMappingURL=editor-module.js.map