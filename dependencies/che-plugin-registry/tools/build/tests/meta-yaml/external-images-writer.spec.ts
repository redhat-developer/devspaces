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

import { Container } from 'inversify';
import { ExternalImagesWriter } from '../../src/meta-yaml/external-images-writer';
import { MetaYamlPluginInfo } from '../../src/meta-yaml/meta-yaml-plugin-info';

describe('Test ExternalImagesWriter', () => {
  let container: Container;

  let metaYamlPlugins: MetaYamlPluginInfo[];
  let externalImagesWriter: ExternalImagesWriter;

  beforeEach(() => {
    metaYamlPlugins = [
      // first plug-in has both containers and init containers
      {
        spec: {
          containers: [{ image: 'container-image1:foo' }, { image: 'container-image2:bar' }],
          initContainers: [{ image: 'init-container-image1:foo' }, { image: 'init-container-image2:bar' }],
        },
      } as any,
      // empty spec
      {
        spec: {},
      } as any,
      // no spec
      {} as any,
    ];
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind('string').toConstantValue('/fake-output').whenTargetNamed('OUTPUT_ROOT_DIRECTORY');

    container.bind(ExternalImagesWriter).toSelf().inSingletonScope();
    externalImagesWriter = container.get(ExternalImagesWriter);
  });

  test('basics', async () => {
    const fsEnsureDirSpy = jest.spyOn(fs, 'ensureDir');
    const fsWriteFileSpy = jest.spyOn(fs, 'writeFile');

    fsEnsureDirSpy.mockReturnValue();
    fsWriteFileSpy.mockReturnValue();

    await externalImagesWriter.write(metaYamlPlugins);

    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(1, '/fake-output/v3');

    const content = `container-image1:foo
container-image2:bar
init-container-image1:foo
init-container-image2:bar`;
    expect(fsWriteFileSpy).toHaveBeenNthCalledWith(1, '/fake-output/v3/external_images.txt', content);
  });
});
