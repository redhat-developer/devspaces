"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.devfileModule = void 0;
const inversify_1 = require("inversify");
const meta_yaml_to_devfile_yaml_1 = require("./meta-yaml-to-devfile-yaml");
const devfileModule = new inversify_1.ContainerModule((bind) => {
    bind(meta_yaml_to_devfile_yaml_1.MetaYamlToDevfileYaml).toSelf().inSingletonScope();
});
exports.devfileModule = devfileModule;
//# sourceMappingURL=devfile-module.js.map