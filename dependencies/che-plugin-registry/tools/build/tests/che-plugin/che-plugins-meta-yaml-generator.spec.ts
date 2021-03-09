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

import { ChePluginMetaInfo } from '../../src/che-plugin/che-plugins-meta-info';
import { ChePluginsMetaYamlGenerator } from '../../src/che-plugin/che-plugins-meta-yaml-generator';
import { Container } from 'inversify';
import { VolumeMountHelper } from '../../src/common/volume-mount-helper';

describe('Test ChePluginsMetaYamlGenerator', () => {
  let container: Container;

  let chePluginsMetaYamlGenerator: ChePluginsMetaYamlGenerator;
  const originalConsoleWarn: any = console.warn;
  const originalConsoleError: any = console.error;

  async function generatePluginMetaInfo(id: string): Promise<ChePluginMetaInfo> {
    const chePlugin: ChePluginMetaInfo = {
      id,
      icon: 'foobar',
      displayName: 'Che machine-exec Service',
      description:
        'Che Plug-in with che-machine-exec service to provide creation terminal or tasks for Eclipse Che workspace containers.',
      repository: 'https://github.com/eclipse/che-machine-exec/',
      firstPublicationDate: '2019-11-07',
      endpoints: [
        {
          name: 'che-machine-exec',
          public: true,
          targetPort: 4444,
          attributes: {
            protocol: 'ws',
            type: 'terminal',
          },
        },
      ],
      containers: [
        {
          name: 'che-machine-exec',
          image: 'quay.io/eclipse/che-machine-exec:nightly',
        },
      ],
      initContainers: [
        {
          name: 'che-machine-exec',
          image: 'quay.io/eclipse/che-machine-exec:nightly',
        },
      ],
    };
    return chePlugin;
  }

  beforeEach(() => {
    jest.restoreAllMocks();
    jest.resetAllMocks();
    console.error = jest.fn();
    console.warn = jest.fn();
    container = new Container();
    container.bind(ChePluginsMetaYamlGenerator).toSelf().inSingletonScope();
    container.bind(VolumeMountHelper).toSelf().inSingletonScope();
    chePluginsMetaYamlGenerator = container.get(ChePluginsMetaYamlGenerator);
  });
  afterEach(() => {
    console.error = originalConsoleError;
    console.warn = originalConsoleWarn;
  });

  test('basics', async () => {
    const chePluginMetaInfo = await generatePluginMetaInfo('my/firstplugin/1.0.0');
    const chePluginMetaInfos: ChePluginMetaInfo[] = [chePluginMetaInfo];
    const result = await chePluginsMetaYamlGenerator.compute(chePluginMetaInfos);
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
    expect(metaYamlInfoSpecContainers[0].image).toBe('quay.io/eclipse/che-machine-exec:nightly');
  });

  test('invalid id', async () => {
    const chePluginMetaInfo = await generatePluginMetaInfo('my/incomplete');
    const chePluginMetaInfos: ChePluginMetaInfo[] = [chePluginMetaInfo];
    await expect(chePluginsMetaYamlGenerator.compute(chePluginMetaInfos)).rejects.toThrow(
      'is not composed of 3 parts separated by /'
    );
  });

  test('non-numeric version', async () => {
    const chePluginMetaInfo = await generatePluginMetaInfo('my/firstplugin/nightly');

    // no endpoint, container and init Containers
    delete chePluginMetaInfo.endpoints;
    delete chePluginMetaInfo.containers;
    delete chePluginMetaInfo.initContainers;

    const chePluginMetaInfos: ChePluginMetaInfo[] = [chePluginMetaInfo];
    const result = await chePluginsMetaYamlGenerator.compute(chePluginMetaInfos);
    expect(result).toBeDefined();
    expect(result.length).toBe(1);
    const metaYamlInfo = result[0];

    const metaYamlInfoSpec = metaYamlInfo.spec;
    expect(metaYamlInfoSpec).toBeDefined();
    const metaYamlInfoSpecContainers = metaYamlInfoSpec.containers;
    expect(metaYamlInfoSpecContainers).toBeUndefined();
  });
});
