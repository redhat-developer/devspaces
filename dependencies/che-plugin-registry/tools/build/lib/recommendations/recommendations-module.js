"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.recommendationsModule = void 0;
const inversify_1 = require("inversify");
const recommendations_analyzer_1 = require("./recommendations-analyzer");
const recommendations_writer_1 = require("./recommendations-writer");
const recommendationsModule = new inversify_1.ContainerModule((bind) => {
    bind(recommendations_analyzer_1.RecommendationsAnalyzer).toSelf().inSingletonScope();
    bind(recommendations_writer_1.RecommendationsWriter).toSelf().inSingletonScope();
});
exports.recommendationsModule = recommendationsModule;
//# sourceMappingURL=recommendations-module.js.map