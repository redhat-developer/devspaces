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
exports.Build = void 0;
const moment = require("moment");
const ora = require("ora");
const path = require("path");
const inversify_1 = require("inversify");
const che_editors_analyzer_1 = require("./editor/che-editors-analyzer");
const che_editors_meta_yaml_generator_1 = require("./editor/che-editors-meta-yaml-generator");
const che_plugins_analyzer_1 = require("./che-plugin/che-plugins-analyzer");
const che_plugins_meta_yaml_generator_1 = require("./che-plugin/che-plugins-meta-yaml-generator");
const che_theia_plugins_analyzer_1 = require("./che-theia-plugin/che-theia-plugins-analyzer");
const che_theia_plugins_meta_yaml_generator_1 = require("./che-theia-plugin/che-theia-plugins-meta-yaml-generator");
const deferred_1 = require("./util/deferred");
const digest_images_helper_1 = require("./meta-yaml/digest-images-helper");
const external_images_writer_1 = require("./meta-yaml/external-images-writer");
const featured_analyzer_1 = require("./featured/featured-analyzer");
const featured_writer_1 = require("./featured/featured-writer");
const index_writer_1 = require("./meta-yaml/index-writer");
const meta_yaml_writer_1 = require("./meta-yaml/meta-yaml-writer");
const recommendations_analyzer_1 = require("./recommendations/recommendations-analyzer");
const recommendations_writer_1 = require("./recommendations/recommendations-writer");
const vsix_url_analyzer_1 = require("./extensions/vsix-url-analyzer");
let Build = class Build {
    analyzeCheTheiaPlugin(cheTheiaPlugin, vsixExtensionUri) {
        return __awaiter(this, void 0, void 0, function* () {
            const vsixInfo = {
                uri: vsixExtensionUri,
                cheTheiaPlugin,
            };
            cheTheiaPlugin.vsixInfos.set(vsixExtensionUri, vsixInfo);
            yield this.vsixUrlAnalyzer.analyze(vsixInfo);
        });
    }
    updateTask(promise, task, success, failureMessage) {
        promise.then(success, () => task.fail(failureMessage));
    }
    analyzeCheTheiaPluginsYaml() {
        return __awaiter(this, void 0, void 0, function* () {
            const cheTheiaPluginsPath = path.resolve(this.pluginRegistryRootDirectory, 'che-theia-plugins.yaml');
            const cheTheiaPluginsYaml = yield this.wrapIntoTask('Read che-theia-plugins.yaml file', this.cheTheiaPluginsAnalyzer.analyze(cheTheiaPluginsPath));
            const analyzingCheTheiaPlugins = yield Promise.all(cheTheiaPluginsYaml.plugins.map((cheTheiaPluginYaml) => __awaiter(this, void 0, void 0, function* () {
                const extensions = cheTheiaPluginYaml.extensions || [];
                const vsixInfos = new Map();
                const id = cheTheiaPluginYaml.id;
                const featured = cheTheiaPluginYaml.featured || false;
                const aliases = cheTheiaPluginYaml.aliases || [];
                const sidecar = cheTheiaPluginYaml.sidecar;
                const repository = cheTheiaPluginYaml.repository;
                return { id, sidecar, aliases, extensions, featured, vsixInfos, repository };
            })));
            let current = 0;
            const title = 'Download/Unpack/Analyze CheTheiaPlugins in parallel (may take a while)';
            const downloadAndAnalyzeTask = ora(title).start();
            const deferred = new deferred_1.Deferred();
            this.wrapIntoTask(title, deferred.promise, downloadAndAnalyzeTask);
            yield Promise.all(analyzingCheTheiaPlugins.map((cheTheiaPlugin) => __awaiter(this, void 0, void 0, function* () {
                const analyzePromise = Promise.all(cheTheiaPlugin.extensions.map((vsixExtension) => __awaiter(this, void 0, void 0, function* () { return this.analyzeCheTheiaPlugin(cheTheiaPlugin, vsixExtension); })));
                this.updateTask(analyzePromise, downloadAndAnalyzeTask, () => {
                    current++;
                    downloadAndAnalyzeTask.text = `${title} [${current}/${analyzingCheTheiaPlugins.length}] ...`;
                }, `Error analyzing extensions ${cheTheiaPlugin.extensions} from ${cheTheiaPlugin.repository.url}`);
                return analyzePromise;
            })));
            deferred.resolve();
            const analyzingCheTheiaPluginsWithIds = analyzingCheTheiaPlugins.map(plugin => {
                let id;
                if (plugin.id) {
                    id = plugin.id;
                }
                else {
                    const firstExtension = plugin.extensions[0];
                    const vsixDetails = plugin.vsixInfos.get(firstExtension);
                    const packageInfo = vsixDetails === null || vsixDetails === void 0 ? void 0 : vsixDetails.packageJson;
                    if (!packageInfo) {
                        throw new Error(`Unable to find a package.json file for extension ${firstExtension}`);
                    }
                    const publisher = packageInfo.publisher;
                    if (!publisher) {
                        throw new Error(`Unable to find a publisher field in package.json file for extension ${firstExtension}`);
                    }
                    const name = packageInfo.name;
                    if (!name) {
                        throw new Error(`Unable to find a name field in package.json file for extension ${firstExtension}`);
                    }
                    id = `${publisher}/${name}`.toLowerCase();
                }
                return Object.assign(Object.assign({}, plugin), { id });
            });
            return analyzingCheTheiaPluginsWithIds;
        });
    }
    analyzeCheEditorsYaml() {
        return __awaiter(this, void 0, void 0, function* () {
            const cheEditorsPath = path.resolve(this.pluginRegistryRootDirectory, 'che-editors.yaml');
            const cheEditorsYaml = yield this.cheEditorsAnalyzer.analyze(cheEditorsPath);
            const cheEditors = yield Promise.all(cheEditorsYaml.editors.map((cheEditorYaml) => __awaiter(this, void 0, void 0, function* () {
                const cheEditorMetaInfo = Object.assign({}, cheEditorYaml);
                return cheEditorMetaInfo;
            })));
            return cheEditors;
        });
    }
    analyzeChePluginsYaml() {
        return __awaiter(this, void 0, void 0, function* () {
            const chePluginsPath = path.resolve(this.pluginRegistryRootDirectory, 'che-plugins.yaml');
            const chePluginsYaml = yield this.chePluginsAnalyzer.analyze(chePluginsPath);
            const chePlugins = yield Promise.all(chePluginsYaml.plugins.map((chePluginYaml) => __awaiter(this, void 0, void 0, function* () {
                const chePluginMetaInfo = Object.assign({}, chePluginYaml);
                return chePluginMetaInfo;
            })));
            return chePlugins;
        });
    }
    wrapIntoTask(title, promise, customTask) {
        return __awaiter(this, void 0, void 0, function* () {
            let task;
            if (customTask) {
                task = customTask;
            }
            else {
                task = ora(title).start();
            }
            if (promise) {
                promise.then(() => task.succeed(), () => task.fail());
            }
            return promise;
        });
    }
    build() {
        return __awaiter(this, void 0, void 0, function* () {
            const start = moment();
            const cheTheiaPlugins = yield this.analyzeCheTheiaPluginsYaml();
            const cheTheiaPluginsMetaYaml = yield this.wrapIntoTask('Compute meta.yaml for che-theia-plugins', this.cheTheiaPluginsMetaYamlGenerator.compute(cheTheiaPlugins));
            const cheEditors = yield this.wrapIntoTask('Analyze che-editors.yaml file', this.analyzeCheEditorsYaml());
            const cheEditorsMetaYaml = yield this.wrapIntoTask('Compute meta.yaml for che-editors', this.cheEditorsMetaYamlGenerator.compute(cheEditors));
            const chePlugins = yield this.wrapIntoTask('Analyze che-plugins.yaml file', this.analyzeChePluginsYaml());
            const chePluginsMetaYaml = yield this.wrapIntoTask('Compute meta.yaml for che-plugins', this.chePluginsMetaYamlGenerator.compute(chePlugins));
            const computedYamls = [...cheTheiaPluginsMetaYaml, ...cheEditorsMetaYaml, ...chePluginsMetaYaml];
            const allMetaYamls = computedYamls;
            yield this.wrapIntoTask('Generate v3/external_images.txt', this.externalImagesWriter.write(allMetaYamls));
            const generatedYamls = yield this.wrapIntoTask('Write meta.yamls in v3/plugins folder', this.metaYamlWriter.write(allMetaYamls));
            yield this.wrapIntoTask('Generate v3/plugins/index.json file', this.indexWriter.write(generatedYamls));
            const jsonOutput = yield this.wrapIntoTask('Generates Che-Theia featured.json file', this.featuredAnalyzer.generate(cheTheiaPlugins));
            yield this.wrapIntoTask('Write Che-Theia featured.json file', this.featuredWriter.writeReport(jsonOutput));
            const recommendations = yield this.wrapIntoTask('Generate Che-Theia recommendations files', this.recommendationsAnalyzer.generate(cheTheiaPlugins));
            yield this.wrapIntoTask('Write Che-Theia recommentations files', this.recommendationsWriter.writeRecommendations(recommendations));
            const end = moment();
            const duration = moment.duration(start.diff(end)).humanize();
            console.log(`🎉 Successfully generated in ${this.outputRootDirectory}. Took ${duration}.`);
        });
    }
};
__decorate([
    inversify_1.inject('string[]'),
    inversify_1.named('ARGUMENTS'),
    __metadata("design:type", Array)
], Build.prototype, "args", void 0);
__decorate([
    inversify_1.inject('string'),
    inversify_1.named('PLUGIN_REGISTRY_ROOT_DIRECTORY'),
    __metadata("design:type", String)
], Build.prototype, "pluginRegistryRootDirectory", void 0);
__decorate([
    inversify_1.inject('string'),
    inversify_1.named('OUTPUT_ROOT_DIRECTORY'),
    __metadata("design:type", String)
], Build.prototype, "outputRootDirectory", void 0);
__decorate([
    inversify_1.inject(featured_analyzer_1.FeaturedAnalyzer),
    __metadata("design:type", featured_analyzer_1.FeaturedAnalyzer)
], Build.prototype, "featuredAnalyzer", void 0);
__decorate([
    inversify_1.inject(che_theia_plugins_meta_yaml_generator_1.CheTheiaPluginsMetaYamlGenerator),
    __metadata("design:type", che_theia_plugins_meta_yaml_generator_1.CheTheiaPluginsMetaYamlGenerator)
], Build.prototype, "cheTheiaPluginsMetaYamlGenerator", void 0);
__decorate([
    inversify_1.inject(che_editors_meta_yaml_generator_1.CheEditorsMetaYamlGenerator),
    __metadata("design:type", che_editors_meta_yaml_generator_1.CheEditorsMetaYamlGenerator)
], Build.prototype, "cheEditorsMetaYamlGenerator", void 0);
__decorate([
    inversify_1.inject(che_plugins_meta_yaml_generator_1.ChePluginsMetaYamlGenerator),
    __metadata("design:type", che_plugins_meta_yaml_generator_1.ChePluginsMetaYamlGenerator)
], Build.prototype, "chePluginsMetaYamlGenerator", void 0);
__decorate([
    inversify_1.inject(meta_yaml_writer_1.MetaYamlWriter),
    __metadata("design:type", meta_yaml_writer_1.MetaYamlWriter)
], Build.prototype, "metaYamlWriter", void 0);
__decorate([
    inversify_1.inject(external_images_writer_1.ExternalImagesWriter),
    __metadata("design:type", external_images_writer_1.ExternalImagesWriter)
], Build.prototype, "externalImagesWriter", void 0);
__decorate([
    inversify_1.inject(index_writer_1.IndexWriter),
    __metadata("design:type", index_writer_1.IndexWriter)
], Build.prototype, "indexWriter", void 0);
__decorate([
    inversify_1.inject(digest_images_helper_1.DigestImagesHelper),
    __metadata("design:type", digest_images_helper_1.DigestImagesHelper)
], Build.prototype, "digestImagesHelper", void 0);
__decorate([
    inversify_1.inject(featured_writer_1.FeaturedWriter),
    __metadata("design:type", featured_writer_1.FeaturedWriter)
], Build.prototype, "featuredWriter", void 0);
__decorate([
    inversify_1.inject(recommendations_analyzer_1.RecommendationsAnalyzer),
    __metadata("design:type", recommendations_analyzer_1.RecommendationsAnalyzer)
], Build.prototype, "recommendationsAnalyzer", void 0);
__decorate([
    inversify_1.inject(recommendations_writer_1.RecommendationsWriter),
    __metadata("design:type", recommendations_writer_1.RecommendationsWriter)
], Build.prototype, "recommendationsWriter", void 0);
__decorate([
    inversify_1.inject(vsix_url_analyzer_1.VsixUrlAnalyzer),
    __metadata("design:type", vsix_url_analyzer_1.VsixUrlAnalyzer)
], Build.prototype, "vsixUrlAnalyzer", void 0);
__decorate([
    inversify_1.inject(che_theia_plugins_analyzer_1.CheTheiaPluginsAnalyzer),
    __metadata("design:type", che_theia_plugins_analyzer_1.CheTheiaPluginsAnalyzer)
], Build.prototype, "cheTheiaPluginsAnalyzer", void 0);
__decorate([
    inversify_1.inject(che_editors_analyzer_1.CheEditorsAnalyzer),
    __metadata("design:type", che_editors_analyzer_1.CheEditorsAnalyzer)
], Build.prototype, "cheEditorsAnalyzer", void 0);
__decorate([
    inversify_1.inject(che_plugins_analyzer_1.ChePluginsAnalyzer),
    __metadata("design:type", che_plugins_analyzer_1.ChePluginsAnalyzer)
], Build.prototype, "chePluginsAnalyzer", void 0);
Build = __decorate([
    inversify_1.injectable()
], Build);
exports.Build = Build;
//# sourceMappingURL=build.js.map