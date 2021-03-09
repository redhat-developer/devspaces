"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Deferred = void 0;
class Deferred {
    constructor() {
        this.promise = new Promise((resolve, reject) => {
            this.resolve = resolve;
            this.reject = reject;
        });
    }
}
exports.Deferred = Deferred;
//# sourceMappingURL=deferred.js.map