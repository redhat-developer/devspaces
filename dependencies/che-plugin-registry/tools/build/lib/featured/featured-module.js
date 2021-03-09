"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.featuredModule = void 0;
const inversify_1 = require("inversify");
const featured_analyzer_1 = require("./featured-analyzer");
const featured_writer_1 = require("./featured-writer");
const featuredModule = new inversify_1.ContainerModule((bind) => {
    bind(featured_analyzer_1.FeaturedAnalyzer).toSelf().inSingletonScope();
    bind(featured_writer_1.FeaturedWriter).toSelf().inSingletonScope();
});
exports.featuredModule = featuredModule;
//# sourceMappingURL=featured-module.js.map