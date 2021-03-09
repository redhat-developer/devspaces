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
exports.CheTheiaPluginsMetaYamlGenerator = void 0;
const path = require("path");
const inversify_1 = require("inversify");
const sidecar_1 = require("../sidecar/sidecar");
let CheTheiaPluginsMetaYamlGenerator = class CheTheiaPluginsMetaYamlGenerator {
    readI18nProperty(propertyName, vsixInfo) {
        if (propertyName && propertyName.startsWith('%') && propertyName.endsWith('%')) {
            const propertyWithoutPrefixSuffix = propertyName.substring(1, propertyName.length - 1);
            const nls = vsixInfo.packageNlsJson;
            if (nls) {
                return nls[propertyWithoutPrefixSuffix];
            }
        }
        return propertyName;
    }
    compute(cheTheiaPlugins) {
        return __awaiter(this, void 0, void 0, function* () {
            const metaYamlPluginInfos = yield Promise.all(cheTheiaPlugins.map((chePlugin) => __awaiter(this, void 0, void 0, function* () {
                const type = 'VS Code extension';
                const vsixData = Array.from(chePlugin.vsixInfos.values());
                const firstVsix = vsixData[0];
                const packageJson = firstVsix.packageJson;
                const chePluginOutput = JSON.stringify(chePlugin);
                if (!packageJson) {
                    throw new Error(`No package.json found for ${chePluginOutput}`);
                }
                if (!packageJson.publisher) {
                    throw new Error(`No publisher field in package.json found for ${chePluginOutput}`);
                }
                const publisher = packageJson.publisher.toLowerCase();
                if (!packageJson.name) {
                    throw new Error(`No name field in package.json found for ${chePluginOutput}`);
                }
                const name = packageJson.name.toLowerCase();
                if (!packageJson.version) {
                    throw new Error(`No version field in package.json found for ${chePluginOutput}`);
                }
                const version = packageJson.version;
                let displayName;
                if (packageJson.displayName) {
                    displayName = this.readI18nProperty(packageJson.displayName, firstVsix);
                }
                else if (packageJson.description) {
                    displayName = this.readI18nProperty(packageJson.description, firstVsix);
                }
                else {
                    displayName = name;
                }
                const title = displayName;
                let description;
                if (!packageJson.description) {
                    description = name;
                    console.error(`No description field in package.json found for ${chePluginOutput}`);
                }
                else {
                    description = this.readI18nProperty(packageJson.description, firstVsix);
                }
                let category;
                if (!packageJson.categories || packageJson.categories.length === 0) {
                    console.error(`No categories field in package.json found for ${chePluginOutput}. Using Other type`);
                    category = 'Other';
                }
                else {
                    category = packageJson.categories[0];
                }
                if (!packageJson.icon) {
                    console.warn(`No icon field in package.json found for ${chePluginOutput}`);
                }
                let iconFile;
                if (packageJson.icon && firstVsix.unpackedExtensionRootDir) {
                    iconFile = path.resolve(firstVsix.unpackedExtensionRootDir, packageJson.icon);
                }
                let repository;
                if (packageJson.repository && typeof packageJson.repository === 'string') {
                    repository = packageJson.repository;
                }
                else if (packageJson.repository &&
                    packageJson.repository.url &&
                    typeof packageJson.repository.url === 'string') {
                    repository = packageJson.repository.url;
                }
                else {
                    repository = chePlugin.repository.url;
                    console.warn(`repository field is not a string or repository.url missing in package.json found, using the one from yaml content for ${chePluginOutput}`);
                }
                let firstPublicationDate;
                if (firstVsix.creationDate) {
                    firstPublicationDate = firstVsix.creationDate;
                }
                else {
                    console.error('No creation date');
                    throw new Error(`No creation date found for vsix ${chePluginOutput}`);
                }
                const id = chePlugin.id;
                const latestUpdateDate = new Date().toISOString().slice(0, 10);
                const spec = {};
                if (chePlugin.sidecar) {
                    const sidecarImage = yield this.sidecar.getDockerImageFor(chePlugin);
                    const container = { image: sidecarImage };
                    let endpoints;
                    if (chePlugin.sidecar.name) {
                        container.name = chePlugin.sidecar.name;
                    }
                    if (chePlugin.sidecar.volumeMounts) {
                        container.volumes = chePlugin.sidecar.volumeMounts.map(volume => ({
                            name: volume.name,
                            mountPath: volume.path,
                        }));
                    }
                    if (chePlugin.sidecar.memoryLimit) {
                        container.memoryLimit = chePlugin.sidecar.memoryLimit;
                    }
                    if (chePlugin.sidecar.memoryRequest) {
                        container.memoryRequest = chePlugin.sidecar.memoryRequest;
                    }
                    if (chePlugin.sidecar.cpuRequest) {
                        container.cpuRequest = chePlugin.sidecar.cpuRequest;
                    }
                    if (chePlugin.sidecar.cpuLimit) {
                        container.cpuLimit = chePlugin.sidecar.cpuLimit;
                    }
                    if (chePlugin.sidecar.env) {
                        container.env = chePlugin.sidecar.env;
                    }
                    if (chePlugin.sidecar.mountSources) {
                        container.mountSources = chePlugin.sidecar.mountSources;
                    }
                    if (chePlugin.sidecar.args) {
                        container.args = chePlugin.sidecar.args;
                    }
                    if (chePlugin.sidecar.command) {
                        container.command = chePlugin.sidecar.command;
                    }
                    if (chePlugin.sidecar.endpoints) {
                        container.ports = chePlugin.sidecar.endpoints.map(endpoint => ({ exposedPort: endpoint.targetPort }));
                        endpoints = chePlugin.sidecar.endpoints;
                    }
                    spec.containers = [container];
                    if (endpoints) {
                        spec.endpoints = endpoints;
                    }
                }
                spec.extensions = chePlugin.extensions;
                const vsixInfos = chePlugin.vsixInfos;
                const aliases = chePlugin.aliases;
                return {
                    id,
                    vsixInfos,
                    publisher,
                    name,
                    version,
                    type,
                    displayName,
                    title,
                    description,
                    iconFile,
                    repository,
                    category,
                    firstPublicationDate,
                    latestUpdateDate,
                    spec,
                    aliases,
                };
            })));
            return metaYamlPluginInfos;
        });
    }
};
__decorate([
    inversify_1.inject(sidecar_1.Sidecar),
    __metadata("design:type", sidecar_1.Sidecar)
], CheTheiaPluginsMetaYamlGenerator.prototype, "sidecar", void 0);
CheTheiaPluginsMetaYamlGenerator = __decorate([
    inversify_1.injectable()
], CheTheiaPluginsMetaYamlGenerator);
exports.CheTheiaPluginsMetaYamlGenerator = CheTheiaPluginsMetaYamlGenerator;
//# sourceMappingURL=che-theia-plugins-meta-yaml-generator.js.map