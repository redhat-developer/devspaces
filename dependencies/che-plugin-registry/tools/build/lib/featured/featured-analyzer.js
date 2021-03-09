"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
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
exports.FeaturedAnalyzer = void 0;
const inversify_1 = require("inversify");
let FeaturedAnalyzer = class FeaturedAnalyzer {
    generate(cheTheiaPlugins) {
        return __awaiter(this, void 0, void 0, function* () {
            const featuredCheTheiaPlugins = cheTheiaPlugins.filter(plugin => plugin.featured === true);
            const featuredPlugins = featuredCheTheiaPlugins.map(cheTheiaPlugin => {
                const workspaceContains = [];
                const onLanguages = [];
                const contributeLanguages = [];
                const featuredPlugin = Object.assign(Object.assign({}, cheTheiaPlugin), { onLanguages,
                    workspaceContains,
                    contributeLanguages });
                Array.from(cheTheiaPlugin.vsixInfos.values()).forEach(vsixInfo => {
                    var _a, _b;
                    const activationEvents = ((_a = vsixInfo.packageJson) === null || _a === void 0 ? void 0 : _a.activationEvents) || [];
                    const workspaceContainsList = activationEvents
                        .filter(activationEvent => activationEvent.startsWith('workspaceContains:'))
                        .map(activationEvent => activationEvent.substring('workspaceContains:'.length));
                    const onLanguageList = activationEvents
                        .filter(activationEvent => activationEvent.startsWith('onLanguage:'))
                        .map(activationEvent => activationEvent.substring('onLanguage:'.length));
                    featuredPlugin.workspaceContains.push(...workspaceContainsList);
                    featuredPlugin.onLanguages.push(...onLanguageList);
                    const contributes = ((_b = vsixInfo.packageJson) === null || _b === void 0 ? void 0 : _b.contributes) || { languages: [] };
                    const contributesLanguages = contributes.languages || [];
                    featuredPlugin.contributeLanguages.push(...contributesLanguages);
                    const keepKeys = ['id', 'aliases', 'filenames', 'filenamePatterns'];
                    contributeLanguages.forEach(language => {
                        Object.keys(language).forEach(key => {
                            if (!keepKeys.includes(key)) {
                                delete language[key];
                            }
                        });
                    });
                });
                return featuredPlugin;
            });
            const featuredItems = featuredPlugins.map(featuredPlugin => ({
                id: featuredPlugin.id,
                onLanguages: featuredPlugin.onLanguages,
                workspaceContains: featuredPlugin.workspaceContains,
                contributes: { languages: featuredPlugin.contributeLanguages },
            }));
            const featuredJson = {
                version: '1.0.0',
                featured: featuredItems,
            };
            return featuredJson;
        });
    }
};
FeaturedAnalyzer = __decorate([
    inversify_1.injectable()
], FeaturedAnalyzer);
exports.FeaturedAnalyzer = FeaturedAnalyzer;
//# sourceMappingURL=featured-analyzer.js.map