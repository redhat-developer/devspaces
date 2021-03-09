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
exports.RecommendationsAnalyzer = void 0;
const inversify_1 = require("inversify");
let RecommendationsAnalyzer = class RecommendationsAnalyzer {
    generate(cheTheiaPlugins) {
        return __awaiter(this, void 0, void 0, function* () {
            const recommandedPlugins = cheTheiaPlugins.map(chePlugin => {
                const activationEvents = [];
                const contributeLanguages = [];
                const categories = [];
                const recommandedPlugin = Object.assign(Object.assign({}, chePlugin), { activationEvents,
                    contributeLanguages,
                    categories });
                Array.from(chePlugin.vsixInfos.values()).forEach(vsixInfo => {
                    var _a, _b, _c;
                    const pluginActivationEvents = ((_a = vsixInfo.packageJson) === null || _a === void 0 ? void 0 : _a.activationEvents) || [];
                    recommandedPlugin.activationEvents.push(...pluginActivationEvents);
                    const contributes = ((_b = vsixInfo.packageJson) === null || _b === void 0 ? void 0 : _b.contributes) || { languages: [] };
                    const contributesLanguages = contributes.languages || [];
                    recommandedPlugin.contributeLanguages.push(...contributesLanguages);
                    const pluginCategories = ((_c = vsixInfo.packageJson) === null || _c === void 0 ? void 0 : _c.categories) || [];
                    recommandedPlugin.categories.push(...pluginCategories);
                });
                return recommandedPlugin;
            });
            const perExtensions = new Map();
            const perLanguages = new Map();
            recommandedPlugins.forEach(chePlugin => {
                const onLanguageEvents = chePlugin.activationEvents.filter(event => event.startsWith('onLanguage:'));
                onLanguageEvents.forEach(language => {
                    const languageIdentifier = language.substring('onLanguage:'.length);
                    const existingList = perLanguages.get(languageIdentifier) || [];
                    perLanguages.set(languageIdentifier, existingList);
                    chePlugin.categories.forEach(chePluginCategory => {
                        let recommendationInfoCategory;
                        existingList.forEach(analyzingRecommendationInfoCategory => {
                            if (analyzingRecommendationInfoCategory.category === chePluginCategory) {
                                recommendationInfoCategory = analyzingRecommendationInfoCategory;
                            }
                        });
                        if (!recommendationInfoCategory) {
                            recommendationInfoCategory = { category: chePluginCategory, ids: new Set() };
                            existingList.push(recommendationInfoCategory);
                        }
                        recommendationInfoCategory.ids.add(chePlugin.id);
                    });
                });
                chePlugin.contributeLanguages.forEach(language => {
                    if (language.extensions) {
                        language.extensions.forEach(fileExtension => {
                            const existingList = perExtensions.get(fileExtension) || [];
                            perExtensions.set(fileExtension, existingList);
                            chePlugin.categories.forEach(chePluginCategory => {
                                let recommendationInfoCategory;
                                existingList.forEach(analyzingRecommendationInfoCategory => {
                                    if (analyzingRecommendationInfoCategory.category === chePluginCategory) {
                                        recommendationInfoCategory = analyzingRecommendationInfoCategory;
                                    }
                                });
                                if (!recommendationInfoCategory) {
                                    recommendationInfoCategory = { category: chePluginCategory, ids: new Set() };
                                    existingList.push(recommendationInfoCategory);
                                }
                                recommendationInfoCategory.ids.add(chePlugin.id);
                            });
                        });
                    }
                });
            });
            return { perExtensions, perLanguages };
        });
    }
};
RecommendationsAnalyzer = __decorate([
    inversify_1.injectable()
], RecommendationsAnalyzer);
exports.RecommendationsAnalyzer = RecommendationsAnalyzer;
//# sourceMappingURL=recommendations-analyzer.js.map