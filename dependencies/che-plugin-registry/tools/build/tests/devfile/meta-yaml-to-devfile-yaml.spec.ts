/**********************************************************************
 * Copyright (c) 2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
/* eslint-disable @typescript-eslint/no-explicit-any */
import 'reflect-metadata';

import * as fs from 'fs-extra';
import * as jsYaml from 'js-yaml';
import * as path from 'path';

import { Container } from 'inversify';
import { MetaYamlToDevfileYaml } from '../../src/devfile/meta-yaml-to-devfile-yaml';

describe('Test MetaYamlToDevfileYaml', () => {
  let container: Container;

  let metaYamlToDevfileYaml: MetaYamlToDevfileYaml;

  beforeEach(() => {
    jest.restoreAllMocks();
    jest.resetAllMocks();

    container = new Container();
    container.bind(MetaYamlToDevfileYaml).toSelf().inSingletonScope();
    metaYamlToDevfileYaml = container.get(MetaYamlToDevfileYaml);
  });

  test('machine-exec', async () => {
    const metaYamlPath = path.resolve(__dirname, '..', '_data', 'meta', 'machine-exec-plugin-meta.yaml');
    const metaYamlContent = await fs.readFile(metaYamlPath, 'utf-8');
    const metaYaml = jsYaml.safeLoad(metaYamlContent);
    const devfileYaml = metaYamlToDevfileYaml.convert(metaYaml);
    expect(devfileYaml.schemaVersion).toBe('2.1.0');
    expect(devfileYaml.metadata?.name).toBe('Che machine-exec Service');
    expect(devfileYaml.components).toBeDefined();
    expect(devfileYaml.components?.length).toBe(1);
    const component = devfileYaml.components[0];
    expect(component.name).toBe('che-machine-exec');
    const componentContainer = component.container;
    expect(componentContainer.image).toBe('quay.io/eclipse/che-machine-exec:nightly');
    expect(componentContainer.args).toStrictEqual(['/go/bin/che-machine-exec', '--url', '0.0.0.0:4444']);

    expect(componentContainer.endpoints).toBeDefined();
    expect(componentContainer.endpoints?.length).toBe(1);
    const endpoint = componentContainer.endpoints[0];
    expect(endpoint.name).toBe('che-machine-exec');
    expect(endpoint.exposure).toBe('public');
    const endpointAttributes = endpoint.attributes;
    expect(endpointAttributes.type).toBe('terminal');
  });

  test('che-theia', async () => {
    const metaYamlPath = path.resolve(__dirname, '..', '_data', 'meta', 'che-theia-meta.yaml');
    const metaYamlContent = await fs.readFile(metaYamlPath, 'utf-8');
    const metaYaml = jsYaml.safeLoad(metaYamlContent);
    const devfileYaml = metaYamlToDevfileYaml.convert(metaYaml);
    expect(devfileYaml.schemaVersion).toBe('2.1.0');
    expect(devfileYaml.metadata?.name).toBe('theia-ide');
    expect(devfileYaml.components).toBeDefined();
    expect(devfileYaml.components?.length).toBe(5);
    const theiaIdeComponent = devfileYaml.components[2];
    expect(theiaIdeComponent.name).toBe('theia-ide');
    const theiaIdeComponentContainer = theiaIdeComponent.container;
    expect(theiaIdeComponentContainer.image).toBe('quay.io/eclipse/che-theia:next');

    expect(theiaIdeComponentContainer.endpoints).toBeDefined();
    expect(theiaIdeComponentContainer.endpoints?.length).toBe(7);
    const theiaIdeFirstEndpoint = theiaIdeComponentContainer.endpoints[0];
    expect(theiaIdeFirstEndpoint.name).toBe('theia');
    expect(theiaIdeFirstEndpoint.exposure).toBe('public');
    const theiaIdeFirstEndpointAttributes = theiaIdeFirstEndpoint.attributes;
    expect(theiaIdeFirstEndpointAttributes.type).toBe('ide');

    expect(theiaIdeComponentContainer.env).toBeDefined();
    expect(theiaIdeComponentContainer.env?.length).toBe(4);
    const theiaIdeFirstEnv = theiaIdeComponentContainer.env[0];
    expect(theiaIdeFirstEnv.name).toBe('THEIA_PLUGINS');
    expect(theiaIdeFirstEnv.value).toBe('local-dir:///plugins');

    const theiaHostEnv = theiaIdeComponentContainer.env.find((env: any) => env.name === 'THEIA_HOST');
    expect(theiaHostEnv.name).toBe('THEIA_HOST');
    // 127.0.0.1 should have been replaced by 0.0.0.0
    expect(theiaHostEnv.value).toBe('0.0.0.0');

    expect(theiaIdeComponentContainer.volumeMounts).toBeDefined();
    expect(theiaIdeComponentContainer.volumeMounts?.length).toBe(2);
    const theiaIdeFirstVolumeMount = theiaIdeComponentContainer.volumeMounts[0];
    expect(theiaIdeFirstVolumeMount.name).toBe('plugins');
    expect(theiaIdeFirstVolumeMount.path).toBe('/plugins');

    const remoteRuntimeInjectorComponent = devfileYaml.components[4];
    expect(remoteRuntimeInjectorComponent.name).toBe('remote-runtime-injector');
    const remoteRuntimeInjectorComponentContainer = remoteRuntimeInjectorComponent.container;
    expect(remoteRuntimeInjectorComponentContainer.image).toBe(
      'quay.io/eclipse/che-theia-endpoint-runtime-binary:next'
    );

    const pluginsVolumeComponent = devfileYaml.components[0];
    expect(pluginsVolumeComponent.name).toBe('plugins');
    expect(pluginsVolumeComponent.volume).toStrictEqual({});

    const theiaLocalVolumeComponent = devfileYaml.components[1];
    expect(theiaLocalVolumeComponent.name).toBe('theia-local');
    expect(theiaLocalVolumeComponent.volume).toStrictEqual({});

    const remoteEndpointVolumeComponent = devfileYaml.components[3];
    expect(remoteEndpointVolumeComponent.name).toBe('remote-endpoint');
    expect(remoteEndpointVolumeComponent.volume).toBeDefined();
    expect(remoteEndpointVolumeComponent.volume.ephemeral).toBeTruthy();

    expect(devfileYaml.commands).toBeDefined();
    expect(devfileYaml.commands?.length).toBe(1);
    const devfileFirstCommand = devfileYaml.commands[0];
    expect(devfileFirstCommand.id).toBe('init-container-command');
    expect(devfileFirstCommand.apply).toStrictEqual({ component: 'remote-runtime-injector' });

    expect(devfileYaml.events).toBeDefined();
    expect(devfileYaml.events.preStart).toBeDefined();
    expect(devfileYaml.events?.preStart?.length).toBe(1);
    const preStartFirstEvent = devfileYaml.events.preStart[0];
    expect(preStartFirstEvent).toBe('init-container-command');
  });

  test('no container', async () => {
    const metaYamlPath = path.resolve(__dirname, '..', '_data', 'meta', 'no-container.yaml');
    const metaYamlContent = await fs.readFile(metaYamlPath, 'utf-8');
    const metaYaml = jsYaml.safeLoad(metaYamlContent);
    const devfileYaml = metaYamlToDevfileYaml.convert(metaYaml);
    expect(devfileYaml.schemaVersion).toBe('2.1.0');
    expect(devfileYaml.metadata?.name).toBe('no-container');
    expect(devfileYaml.components).toBeDefined();
    expect(devfileYaml.components?.length).toBe(1);
    const component = devfileYaml.components[0];
    expect(component.name).toBe('foo');
    const componentContainer = component.container;
    expect(componentContainer.image).toBe('quay.io/foobar:next');
  });

  test('vscode extension', async () => {
    const metaYamlPath = path.resolve(__dirname, '..', '_data', 'meta', 'vscode-extension.yaml');
    const metaYamlContent = await fs.readFile(metaYamlPath, 'utf-8');
    const metaYaml = jsYaml.safeLoad(metaYamlContent);
    const devfileYaml = metaYamlToDevfileYaml.convert(metaYaml);
    expect(devfileYaml).toBeUndefined();
  });

  test('container without endpoints', async () => {
    const metaYamlPath = path.resolve(__dirname, '..', '_data', 'meta', 'container-no-endpoints.yaml');
    const metaYamlContent = await fs.readFile(metaYamlPath, 'utf-8');
    const metaYaml = jsYaml.safeLoad(metaYamlContent);
    const devfileYaml = metaYamlToDevfileYaml.convert(metaYaml);
    expect(devfileYaml.schemaVersion).toBe('2.1.0');
    expect(devfileYaml.metadata?.name).toBe('no-endpoint');
    expect(devfileYaml.components).toBeDefined();
    expect(devfileYaml.components?.length).toBe(1);
    const component = devfileYaml.components[0];
    expect(component.name).toBe('no-endpoint');
    const componentContainer = component.container;
    expect(componentContainer.image).toBe('quay.io/no-endpoint');
  });

  test('container with minimal endpoint', async () => {
    const metaYamlPath = path.resolve(__dirname, '..', '_data', 'meta', 'container-minimal-endpoint.yaml');
    const metaYamlContent = await fs.readFile(metaYamlPath, 'utf-8');
    const metaYaml = jsYaml.safeLoad(metaYamlContent);
    const devfileYaml = metaYamlToDevfileYaml.convert(metaYaml);
    expect(devfileYaml.schemaVersion).toBe('2.1.0');
    expect(devfileYaml.metadata?.name).toBe('minimal-endpoint');
    expect(devfileYaml.components).toBeDefined();
    expect(devfileYaml.components?.length).toBe(1);
    const component = devfileYaml.components[0];
    expect(component.name).toBe('minimal-endpoint');
    const componentContainer = component.container;
    expect(componentContainer.image).toBe('quay.io/minimal-endpoint');

    expect(componentContainer.endpoints).toBeDefined();
    expect(componentContainer.endpoints?.length).toBe(1);
    const wwwEndpoint = componentContainer.endpoints[0];
    expect(wwwEndpoint.name).toBe('www');
    expect(wwwEndpoint.exposure).toBeUndefined();
    expect(wwwEndpoint.attributes).toBeUndefined();
  });
});
