"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.chePluginsModule = void 0;
const inversify_1 = require("inversify");
const che_plugins_analyzer_1 = require("./che-plugins-analyzer");
const che_plugins_meta_yaml_generator_1 = require("./che-plugins-meta-yaml-generator");
const chePluginsModule = new inversify_1.ContainerModule((bind) => {
    bind(che_plugins_analyzer_1.ChePluginsAnalyzer).toSelf().inSingletonScope();
    bind(che_plugins_meta_yaml_generator_1.ChePluginsMetaYamlGenerator).toSelf().inSingletonScope();
});
exports.chePluginsModule = chePluginsModule;
//# sourceMappingURL=che-plugins-module.js.map