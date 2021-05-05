/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/

import 'reflect-metadata';

import { ContainerHelper, Containers } from '../../src/common/container-helper';

import { CheEditorMetaInfo } from '../../src/editor/che-editors-meta-info';
import { Container } from 'inversify';
import { VolumeMountHelper } from '../../src/common/volume-mount-helper';

describe('Test ContainerHelper', () => {
  let containerHelper: ContainerHelper;
  let container: Container;
  let cheEditor: CheEditorMetaInfo;

  beforeEach(() => {
    cheEditor = {
      schemaVersion: '2.1.0',
      metadata: {
        displayName: 'theia-ide',
        description: 'Eclipse Theia, get the latest release each day.',
        icon:
          'https://raw.githubusercontent.com/theia-ide/theia/master/logo/theia-logo-no-text-black.svg?sanitize=true',
        name: 'che-editor',
        attributes: {
          version: '5.7.0',
          title: 'Eclipse Theia development version.',
          repository: 'https://github.com/eclipse-che/che-theia',
          firstPublicationDate: '2019-03-07',
        },
      },
      commands: [{ id: 'init-container-command', apply: { component: 'remote-runtime-injector' } }],
      events: {
        preStart: ['init-container-command'],
      },
      components: [
        {
          name: 'theia-ide',
          container: {
            image: 'quay.io/eclipse/che-theia:next',
            env: [
              {
                name: 'THEIA_PLUGINS',
                value: 'local-dir:///plugins',
              },
              {
                name: 'HOSTED_PLUGIN_HOSTNAME',
                value: '0.0.0.0',
              },
              {
                name: 'HOSTED_PLUGIN_PORT',
                value: '3130',
              },
              {
                name: 'THEIA_HOST',
                value: '127.0.0.1',
              },
            ],
            volumeMounts: [
              {
                name: 'plugins',
                path: '/plugins',
              },
            ],
            mountSources: true,
            memoryLimit: '512M',
            endpoints: [
              {
                name: 'theia',
                public: true,
                targetPort: 3100,
                attributes: {
                  protocol: 'http',
                  type: 'ide',
                },
              },
              {
                name: 'webviews',
                public: true,
                targetPort: 3100,
                attributes: {
                  protocol: 'http',
                  type: 'webview',
                },
              },
              {
                name: 'mini-browser',
                public: true,
                targetPort: 3100,
                attributes: {
                  protocol: 'http',
                  type: 'mini-browser',
                },
              },
              {
                name: 'theia-dev',
                public: true,
                targetPort: 3130,
                attributes: {
                  protocol: 'http',
                  type: 'ide-dev',
                },
              },
              {
                name: 'theia-redirect-1',
                public: true,
                targetPort: 13131,
                attributes: {
                  protocol: 'http',
                },
              },
              {
                name: 'theia-redirect-2',
                public: true,
                targetPort: 13132,
                attributes: {
                  protocol: 'http',
                },
              },
              {
                name: 'theia-redirect-3',
                public: true,
                targetPort: 13133,
                attributes: {
                  protocol: 'http',
                },
              },
            ],
          },
          attributes: {
            ports: [
              { exposedPort: 3100 },
              { exposedPort: 3130 },
              { exposedPort: 13131 },
              { exposedPort: 13132 },
              { exposedPort: 13133 },
            ],
          },
        },
        {
          name: 'remote-runtime-injector',
          container: {
            image: 'quay.io/eclipse/che-theia-endpoint-runtime-binary:next',
            volumeMounts: [
              {
                name: 'remote-endpoint',
                path: '/remote-endpoint',
              },
            ],
            env: [
              {
                name: 'PLUGIN_REMOTE_ENDPOINT_EXECUTABLE',
                value: '/remote-endpoint/plugin-remote-endpoint',
              },
              {
                name: 'REMOTE_ENDPOINT_VOLUME_NAME',
                value: 'remote-endpoint',
              },
            ],
          },
        },
        {
          name: 'remote-endpoint',
          volume: { ephemeral: true },
        },
      ],
    };

    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind('string').toConstantValue('/fake-output').whenTargetNamed('OUTPUT_ROOT_DIRECTORY');

    container.bind(ContainerHelper).toSelf().inSingletonScope();
    container.bind(VolumeMountHelper).toSelf().inSingletonScope();
    containerHelper = container.get(ContainerHelper);
  });

  test('basics', async () => {
    const containers: Containers = await containerHelper.resolve(cheEditor);
    expect(containers).toBeDefined();
    expect(containers.containers.length).toBe(1);
    expect(containers.initContainers.length).toBe(1);
    expect(containers.containers[0].ports?.length).toBe(5);
  });

  test('empty components', async () => {
    delete cheEditor.components;
    const containers: Containers = await containerHelper.resolve(cheEditor);
    expect(containers).toBeDefined();
    expect(containers.containers.length).toBe(0);
    expect(containers.initContainers.length).toBe(0);
  });

  test('empty events', async () => {
    delete cheEditor.events;
    const containers: Containers = await containerHelper.resolve(cheEditor);
    expect(containers).toBeDefined();
    expect(containers.containers.length).toBe(2);
    expect(containers.initContainers.length).toBe(0);
  });

  test('empty prestart events', async () => {
    delete cheEditor.events?.preStart;
    const containers: Containers = await containerHelper.resolve(cheEditor);
    expect(containers).toBeDefined();
    expect(containers.containers.length).toBe(2);
    expect(containers.initContainers.length).toBe(0);
  });

  test('empty commands', async () => {
    delete cheEditor.commands;
    const containers: Containers = await containerHelper.resolve(cheEditor);
    expect(containers).toBeDefined();
    expect(containers.containers.length).toBe(2);
    expect(containers.initContainers.length).toBe(0);
  });
});
