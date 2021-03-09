"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MetaYamlToDevfileYaml = void 0;
const inversify_1 = require("inversify");
let MetaYamlToDevfileYaml = class MetaYamlToDevfileYaml {
    componentsFromContainer(container) {
        const components = [];
        const component = {
            name: container.name,
            container: {
                image: container.image,
            },
        };
        if (container.command) {
            component.container.args = container.command;
        }
        if (container.env) {
            component.container.env = container.env;
        }
        if (container.volumes) {
            component.container.volumeMounts = container.volumes.map((volume) => ({
                name: volume.name,
                path: volume.mountPath,
            }));
            container.volumes.map((volume) => {
                const volumeComponent = {
                    name: volume.name,
                    volume: {},
                };
                if (volume.ephemeral === true) {
                    volumeComponent.volume.ephemeral = true;
                }
                components.push(volumeComponent);
            });
        }
        if (container.mountSources) {
            component.container.mountSources = container.mountSources;
        }
        if (container.memoryLimit) {
            component.container.memoryLimit = container.memoryLimit;
        }
        if (container.memoryRequest) {
            component.container.memoryRequest = container.memoryRequest;
        }
        if (container.cpuLimit) {
            component.container.cpuLimit = container.cpuLimit;
        }
        if (container.cpuRequest) {
            component.container.cpuRequest = container.cpuRequest;
        }
        components.push(component);
        return components.map(iteratingComponent => JSON.parse(JSON.stringify(iteratingComponent).replace(/127\.0\.0\.1/g, '0.0.0.0')));
    }
    convert(metaYaml) {
        if (!metaYaml || metaYaml.type === 'VS Code extension') {
            return;
        }
        const devfileYaml = {
            schemaVersion: '2.1.0',
            metadata: {
                name: metaYaml.displayName,
            },
        };
        const metaYamlSpec = metaYaml.spec;
        let components = [];
        if (metaYamlSpec.containers && metaYamlSpec.containers.length === 1) {
            const container = metaYamlSpec.containers[0];
            const componentsFromContainer = this.componentsFromContainer(container);
            const endpoints = [];
            if (metaYamlSpec.endpoints && metaYamlSpec.endpoints.length > 0) {
                metaYamlSpec.endpoints.forEach((endpoint) => {
                    const devfileEndpoint = {
                        name: endpoint.name,
                        attributes: endpoint.attributes,
                    };
                    devfileEndpoint.targetPort = endpoint.targetPort;
                    if (endpoint.public === true) {
                        devfileEndpoint.exposure = 'public';
                    }
                    if (devfileEndpoint.attributes && devfileEndpoint.attributes.secure === true) {
                        devfileEndpoint.secure = false;
                        delete devfileEndpoint.attributes['secure'];
                    }
                    if (devfileEndpoint.attributes && devfileEndpoint.attributes.protocol) {
                        devfileEndpoint.protocol = devfileEndpoint.attributes.protocol;
                        delete devfileEndpoint.attributes['protocol'];
                    }
                    endpoints.push(devfileEndpoint);
                });
            }
            componentsFromContainer[componentsFromContainer.length - 1].container.endpoints = endpoints;
            components = components.concat(componentsFromContainer);
        }
        if (metaYamlSpec.initContainers && metaYamlSpec.initContainers.length === 1) {
            const initContainer = metaYamlSpec.initContainers[0];
            const componentsFromContainer = this.componentsFromContainer(initContainer);
            const commands = devfileYaml.commands || [];
            commands.push({
                id: 'init-container-command',
                apply: {
                    component: componentsFromContainer[componentsFromContainer.length - 1].name,
                },
            });
            devfileYaml.commands = commands;
            const events = devfileYaml.events || {};
            const preStartEvents = events.preStart || [];
            preStartEvents.push('init-container-command');
            events.preStart = preStartEvents;
            devfileYaml.events = events;
            components = components.concat(componentsFromContainer);
        }
        devfileYaml.components = components;
        return devfileYaml;
    }
};
MetaYamlToDevfileYaml = __decorate([
    inversify_1.injectable()
], MetaYamlToDevfileYaml);
exports.MetaYamlToDevfileYaml = MetaYamlToDevfileYaml;
//# sourceMappingURL=meta-yaml-to-devfile-yaml.js.map