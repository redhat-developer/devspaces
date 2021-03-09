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
exports.Main = void 0;
const build_1 = require("./build");
const inversify_binding_1 = require("./inversify-binding");
class Main {
    doStart() {
        return __awaiter(this, void 0, void 0, function* () {
            const inversifyBinbding = new inversify_binding_1.InversifyBinding();
            const container = yield inversifyBinbding.initBindings();
            const build = container.get(build_1.Build);
            return build.build();
        });
    }
    start() {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                yield this.doStart();
                return true;
            }
            catch (error) {
                console.error('stack=' + error.stack);
                console.error('Unable to start', error);
                return false;
            }
        });
    }
}
exports.Main = Main;
//# sourceMappingURL=main.js.map