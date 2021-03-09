"use strict";
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
exports.InversifyBinding = void 0;
require("reflect-metadata");
require("reflect-metadata");
const fs = require("fs-extra");
const path = require("path");
const build_1 = require("./build");
const inversify_1 = require("inversify");
const che_plugins_module_1 = require("./che-plugin/che-plugins-module");
const che_theia_plugin_module_1 = require("./che-theia-plugin/che-theia-plugin-module");
const common_module_1 = require("./common/common-module");
const devfile_module_1 = require("./devfile/devfile-module");
const editor_module_1 = require("./editor/editor-module");
const extension_module_1 = require("./extensions/extension-module");
const featured_module_1 = require("./featured/featured-module");
const meta_yaml_module_1 = require("./meta-yaml/meta-yaml-module");
const recommendations_module_1 = require("./recommendations/recommendations-module");
const registry_module_1 = require("./registry/registry-module");
const plugin_module_1 = require("./sidecar/plugin-module");
class InversifyBinding {
    initBindings() {
        return __awaiter(this, void 0, void 0, function* () {
            let outputDirectory = '/tmp/che-plugin-registry/output-folder';
            const downloadDirectory = '/tmp/che-plugin-registry/download-folder';
            const unpackedDirectory = '/tmp/che-plugin-registry/unpack-folder';
            const pluginRegistryRootDirectory = path.resolve(__dirname, '..', '..', '..');
            let embedVsix = false;
            const args = process.argv.slice(2);
            args.forEach(arg => {
                if (arg.startsWith('--output-folder:')) {
                    outputDirectory = arg.substring('--output-folder:'.length);
                }
                if (arg.startsWith('--embed-vsix:')) {
                    embedVsix = 'true' === arg.substring('--embed-vsix:'.length);
                }
            });
            this.container = new inversify_1.Container();
            this.container.load(common_module_1.commonModule);
            this.container.load(che_plugins_module_1.chePluginsModule);
            this.container.load(che_theia_plugin_module_1.cheTheiaPluginModule);
            this.container.load(devfile_module_1.devfileModule);
            this.container.load(editor_module_1.editorModule);
            this.container.load(extension_module_1.extensionsModule);
            this.container.load(featured_module_1.featuredModule);
            this.container.load(meta_yaml_module_1.metaYamlModule);
            this.container.load(recommendations_module_1.recommendationsModule);
            this.container.load(registry_module_1.registryModule);
            this.container.load(plugin_module_1.sidecarModule);
            this.container.bind(build_1.Build).toSelf().inSingletonScope();
            this.container.bind('string[]').toConstantValue(args).whenTargetNamed('ARGUMENTS');
            this.container.bind('string').toConstantValue(unpackedDirectory).whenTargetNamed('UNPACKED_ROOT_DIRECTORY');
            this.container.bind('string').toConstantValue(downloadDirectory).whenTargetNamed('DOWNLOAD_ROOT_DIRECTORY');
            this.container
                .bind('string')
                .toConstantValue(pluginRegistryRootDirectory)
                .whenTargetNamed('PLUGIN_REGISTRY_ROOT_DIRECTORY');
            this.container.bind('string').toConstantValue(outputDirectory).whenTargetNamed('OUTPUT_ROOT_DIRECTORY');
            this.container.bind('boolean').toConstantValue(embedVsix).whenTargetNamed('EMBED_VSIX');
            yield fs.mkdirs(unpackedDirectory);
            yield fs.mkdirs(downloadDirectory);
            yield fs.mkdirs(outputDirectory);
            return this.container;
        });
    }
}
exports.InversifyBinding = InversifyBinding;
//# sourceMappingURL=inversify-binding.js.map