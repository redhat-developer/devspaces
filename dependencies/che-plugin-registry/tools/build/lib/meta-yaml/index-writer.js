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
exports.IndexWriter = void 0;
const fs = require("fs-extra");
const path = require("path");
const inversify_1 = require("inversify");
let IndexWriter = class IndexWriter {
    getLinks(plugin) {
        const links = {
            self: `/v3/plugins/${plugin.id}`,
        };
        if (plugin.type === 'Che Editor' || plugin.type === 'Che Plugin') {
            links.devfile = `/v3/plugins/${plugin.id}/devfile.yaml`;
        }
        return links;
    }
    write(generatedMetaYamlPluginInfos) {
        return __awaiter(this, void 0, void 0, function* () {
            const v3PluginsFolder = path.resolve(this.outputRootDirectory, 'v3', 'plugins');
            yield fs.ensureDir(v3PluginsFolder);
            const externalImagesFile = path.join(v3PluginsFolder, 'index.json');
            const indexValues = generatedMetaYamlPluginInfos.map(plugin => ({
                id: plugin.id,
                description: plugin.description,
                displayName: plugin.displayName,
                links: this.getLinks(plugin),
                name: plugin.name,
                publisher: plugin.publisher,
                type: plugin.type,
                version: plugin.version,
            }));
            indexValues.sort((pluginA, pluginB) => pluginA.id.localeCompare(pluginB.id));
            yield fs.writeFile(externalImagesFile, JSON.stringify(indexValues, undefined, 2));
        });
    }
};
__decorate([
    inversify_1.inject('string'),
    inversify_1.named('OUTPUT_ROOT_DIRECTORY'),
    __metadata("design:type", String)
], IndexWriter.prototype, "outputRootDirectory", void 0);
IndexWriter = __decorate([
    inversify_1.injectable()
], IndexWriter);
exports.IndexWriter = IndexWriter;
//# sourceMappingURL=index-writer.js.map