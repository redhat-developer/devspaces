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
var MetaYamlWriter_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.MetaYamlWriter = void 0;
const fs = require("fs-extra");
const jsyaml = require("js-yaml");
const moment = require("moment");
const path = require("path");
const inversify_1 = require("inversify");
const meta_yaml_to_devfile_yaml_1 = require("../devfile/meta-yaml-to-devfile-yaml");
let MetaYamlWriter = MetaYamlWriter_1 = class MetaYamlWriter {
    convertIdToPublisherAndName(id) {
        const values = id.split('/');
        return [values[0], values[1]];
    }
    write(metaYamlPluginInfos) {
        return __awaiter(this, void 0, void 0, function* () {
            const pluginsFolder = path.resolve(this.outputRootDirectory, 'v3', 'plugins');
            yield fs.ensureDir(pluginsFolder);
            const imagesFolder = path.resolve(this.outputRootDirectory, 'v3', 'images');
            yield fs.ensureDir(imagesFolder);
            const resourcesFolder = path.resolve(this.outputRootDirectory, 'v3', 'resources');
            yield fs.ensureDir(resourcesFolder);
            const apiVersion = 'v2';
            const metaYamlPluginGenerated = [];
            yield Promise.all(metaYamlPluginInfos.map((plugin) => __awaiter(this, void 0, void 0, function* () {
                const id = plugin.id;
                let version = plugin.version;
                const name = plugin.name;
                const publisher = plugin.publisher;
                const type = plugin.type;
                let icon;
                const iconFile = plugin.iconFile;
                if (iconFile) {
                    const fileExtensionIcon = path.extname(path.basename(iconFile)).toLowerCase();
                    const destIconFileName = `${publisher}-${name}-icon${fileExtensionIcon}`;
                    yield fs.copyFile(iconFile, path.resolve(imagesFolder, destIconFileName));
                    icon = `/v3/images/${destIconFileName}`;
                }
                else {
                    icon = MetaYamlWriter_1.DEFAULT_ICON;
                }
                if (this.embedVsix) {
                    if (plugin.spec && plugin.spec.extensions) {
                        yield Promise.all(plugin.spec.extensions.map((extension, index) => __awaiter(this, void 0, void 0, function* () {
                            const vsixInfo = plugin.vsixInfos.get(extension);
                            if (vsixInfo && vsixInfo.downloadedArchive) {
                                const directoryPattern = path
                                    .dirname(extension)
                                    .replace('http://', '')
                                    .replace('https://', '')
                                    .replace(/[^a-zA-Z0-9-/]/g, '_');
                                const filePattern = path.basename(extension);
                                const destFolder = path.join(resourcesFolder, directoryPattern);
                                const destFile = path.join(destFolder, filePattern);
                                yield fs.ensureDir(destFolder);
                                yield fs.copyFile(vsixInfo.downloadedArchive, destFile);
                                plugin.spec.extensions[index] = `relative:extension/resources/${directoryPattern}/${filePattern}`;
                            }
                        })));
                    }
                }
                const displayName = plugin.displayName;
                const title = plugin.title;
                const description = plugin.description;
                const category = plugin.category;
                const repository = plugin.repository;
                const firstPublicationDate = plugin.firstPublicationDate;
                const latestUpdateDate = moment.utc().format('YYYY-MM-DD');
                const spec = plugin.spec;
                let aliases;
                if (plugin.aliases) {
                    aliases = plugin.aliases;
                }
                else {
                    aliases = [];
                }
                const pluginsToGenerate = [
                    this.convertIdToPublisherAndName(id),
                    ...aliases.map(item => this.convertIdToPublisherAndName(item)),
                ];
                const promises = [];
                yield Promise.all(pluginsToGenerate.map((pluginToWrite) => __awaiter(this, void 0, void 0, function* () {
                    if (!plugin.disableLatest) {
                        version = 'latest';
                    }
                    const metaYaml = {
                        apiVersion,
                        publisher: pluginToWrite[0],
                        name: pluginToWrite[1],
                        version,
                        type,
                        displayName,
                        title,
                        description,
                        icon,
                        category,
                        repository,
                        firstPublicationDate,
                        latestUpdateDate,
                    };
                    const computedId = `${metaYaml.publisher}/${metaYaml.name}`;
                    if (computedId !== id) {
                        metaYaml.deprecate = {
                            automigrate: true,
                            migrateTo: `${id}/latest`,
                        };
                    }
                    metaYaml.spec = spec;
                    const yamlString = jsyaml.safeDump(metaYaml, { lineWidth: 120 });
                    const generated = Object.assign({}, metaYaml);
                    generated.id = `${computedId}/${version}`;
                    metaYamlPluginGenerated.push(generated);
                    const pluginPath = path.resolve(pluginsFolder, computedId, version, 'meta.yaml');
                    yield fs.ensureDir(path.dirname(pluginPath));
                    promises.push(fs.writeFile(pluginPath, yamlString));
                    const devfileYaml = this.metaYamlToDevfileYaml.convert(metaYaml);
                    if (devfileYaml) {
                        const devfilePath = path.resolve(pluginsFolder, computedId, version, 'devfile.yaml');
                        const devfileYamlString = jsyaml.safeDump(devfileYaml, { lineWidth: 120 });
                        promises.push(fs.writeFile(devfilePath, devfileYamlString));
                    }
                })));
                return Promise.all(promises);
            })));
            return metaYamlPluginGenerated;
        });
    }
};
MetaYamlWriter.DEFAULT_ICON = '/v3/images/eclipse-che-logo.png';
__decorate([
    inversify_1.inject('string'),
    inversify_1.named('OUTPUT_ROOT_DIRECTORY'),
    __metadata("design:type", String)
], MetaYamlWriter.prototype, "outputRootDirectory", void 0);
__decorate([
    inversify_1.inject('boolean'),
    inversify_1.named('EMBED_VSIX'),
    __metadata("design:type", Boolean)
], MetaYamlWriter.prototype, "embedVsix", void 0);
__decorate([
    inversify_1.inject(meta_yaml_to_devfile_yaml_1.MetaYamlToDevfileYaml),
    __metadata("design:type", meta_yaml_to_devfile_yaml_1.MetaYamlToDevfileYaml)
], MetaYamlWriter.prototype, "metaYamlToDevfileYaml", void 0);
MetaYamlWriter = MetaYamlWriter_1 = __decorate([
    inversify_1.injectable()
], MetaYamlWriter);
exports.MetaYamlWriter = MetaYamlWriter;
//# sourceMappingURL=meta-yaml-writer.js.map