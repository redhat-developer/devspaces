/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
/* eslint-disable @typescript-eslint/no-explicit-any */
import 'reflect-metadata';

import { CheEditorMetaInfo } from '../../src/editor/che-editors-meta-info';
import { CheEditorsMetaYamlGenerator } from '../../src/editor/che-editors-meta-yaml-generator';
import { Container } from 'inversify';
import { VolumeMountHelper } from '../../src/common/volume-mount-helper';

describe('Test ChePluginsMetaYamlGenerator', () => {
  let container: Container;

  let cheEditorsMetaYamlGenerator: CheEditorsMetaYamlGenerator;
  const originalConsoleWarn: any = console.warn;
  const originalConsoleError: any = console.error;

  async function generateEditorMetaInfo(id: string): Promise<CheEditorMetaInfo> {
    const cheEditor: CheEditorMetaInfo = {
      id,
      title: 'Eclipse Theia development version.',
      displayName: 'theia-ide',
      description: 'Eclipse Theia, get the latest release each day.',
      icon: 'https://raw.githubusercontent.com/theia-ide/theia/master/logo/theia-logo-no-text-black.svg?sanitize=true',
      repository: 'https://github.com/eclipse/che-theia',
      firstPublicationDate: '2019-03-07',
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
      containers: [
        {
          name: 'theia-ide',
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
        },
      ],
      initContainers: [
        {
          name: 'remote-runtime-injector',
          image: 'quay.io/eclipse/che-theia-endpoint-runtime-binary:next',
          volumeMounts: [
            {
              name: 'remote-endpoint',
              path: '/remote-endpoint',
              ephemeral: true,
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
      ],
    };
    return cheEditor;
  }

  beforeEach(() => {
    jest.restoreAllMocks();
    jest.resetAllMocks();
    console.error = jest.fn();
    console.warn = jest.fn();
    container = new Container();
    container.bind(CheEditorsMetaYamlGenerator).toSelf().inSingletonScope();
    container.bind(VolumeMountHelper).toSelf().inSingletonScope();
    cheEditorsMetaYamlGenerator = container.get(CheEditorsMetaYamlGenerator);
  });
  afterEach(() => {
    console.error = originalConsoleError;
    console.warn = originalConsoleWarn;
  });

  test('basics', async () => {
    const cheEditorMetaInfo = await generateEditorMetaInfo('my/firstplugin/1.0.0');
    const cheEditorMetaInfos: CheEditorMetaInfo[] = [cheEditorMetaInfo];
    const result = await cheEditorsMetaYamlGenerator.compute(cheEditorMetaInfos);
    expect(result).toBeDefined();
    expect(result.length).toBe(1);
    const metaYamlInfo = result[0];

    const metaYamlInfoSpec = metaYamlInfo.spec;
    expect(metaYamlInfoSpec).toBeDefined();
    const metaYamlInfoSpecContainers = metaYamlInfoSpec.containers;
    if (!metaYamlInfoSpecContainers) {
      throw new Error('No spec containers');
    }
    expect(metaYamlInfoSpecContainers).toBeDefined();
    expect(metaYamlInfoSpecContainers.length).toBe(1);
    expect(metaYamlInfoSpecContainers[0].image).toBe('quay.io/eclipse/che-theia:next');
  });

  test('invalid id', async () => {
    const cheEditorMetaInfo = await generateEditorMetaInfo('my/incomplete');
    const cheEditorMetaInfos: CheEditorMetaInfo[] = [cheEditorMetaInfo];
    await expect(cheEditorsMetaYamlGenerator.compute(cheEditorMetaInfos)).rejects.toThrow(
      'is not composed of 3 parts separated by /'
    );
  });

  test('non-numeric version', async () => {
    const cheEditorMetaInfo = await generateEditorMetaInfo('my/firstplugin/nightly');

    // no endpoint, container and init Containers
    delete cheEditorMetaInfo.endpoints;
    delete cheEditorMetaInfo.containers;
    delete cheEditorMetaInfo.initContainers;

    const cheEditorMetaInfos: CheEditorMetaInfo[] = [cheEditorMetaInfo];
    const result = await cheEditorsMetaYamlGenerator.compute(cheEditorMetaInfos);
    expect(result).toBeDefined();
    expect(result.length).toBe(1);
    const metaYamlInfo = result[0];

    const metaYamlInfoSpec = metaYamlInfo.spec;
    expect(metaYamlInfoSpec).toBeDefined();
    const metaYamlInfoSpecContainers = metaYamlInfoSpec.containers;
    expect(metaYamlInfoSpecContainers).toBeUndefined();
  });
});
