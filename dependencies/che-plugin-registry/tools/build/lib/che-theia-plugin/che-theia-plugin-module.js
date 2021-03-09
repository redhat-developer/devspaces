"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cheTheiaPluginModule = void 0;
const inversify_1 = require("inversify");
const che_theia_plugins_analyzer_1 = require("./che-theia-plugins-analyzer");
const che_theia_plugins_meta_yaml_generator_1 = require("./che-theia-plugins-meta-yaml-generator");
const cheTheiaPluginModule = new inversify_1.ContainerModule((bind) => {
    bind(che_theia_plugins_analyzer_1.CheTheiaPluginsAnalyzer).toSelf().inSingletonScope();
    bind(che_theia_plugins_meta_yaml_generator_1.CheTheiaPluginsMetaYamlGenerator).toSelf().inSingletonScope();
});
exports.cheTheiaPluginModule = cheTheiaPluginModule;
//# sourceMappingURL=che-theia-plugin-module.js.map