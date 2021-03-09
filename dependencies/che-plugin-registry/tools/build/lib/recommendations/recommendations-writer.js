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
exports.RecommendationsWriter = void 0;
const fs = require("fs-extra");
const path = require("path");
const inversify_1 = require("inversify");
let RecommendationsWriter = class RecommendationsWriter {
    writeRecommendations(recommendationResult) {
        return __awaiter(this, void 0, void 0, function* () {
            const recommendationsFolder = path.resolve(this.outputRootDirectory, 'v3', 'che-theia', 'recommendations');
            const languageFolder = path.resolve(recommendationsFolder, 'language');
            yield fs.ensureDir(languageFolder);
            yield Promise.all(Array.from(recommendationResult.perLanguages.entries())
                .sort()
                .map(entry => {
                const languageID = entry[0];
                const langCategories = entry[1];
                const languageFile = path.resolve(languageFolder, `${languageID}.json`);
                const perLanguageEntries = langCategories.map(recommendationCategory => ({
                    category: recommendationCategory.category,
                    ids: Array.from(recommendationCategory.ids),
                }));
                return fs.writeFile(languageFile, `${JSON.stringify(perLanguageEntries, undefined, 2)}\n`);
            }));
        });
    }
};
__decorate([
    inversify_1.inject('string'),
    inversify_1.named('OUTPUT_ROOT_DIRECTORY'),
    __metadata("design:type", String)
], RecommendationsWriter.prototype, "outputRootDirectory", void 0);
RecommendationsWriter = __decorate([
    inversify_1.injectable()
], RecommendationsWriter);
exports.RecommendationsWriter = RecommendationsWriter;
//# sourceMappingURL=recommendations-writer.js.map