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

import { Container } from 'inversify';
import { DigestImagesHelper } from '../../src/meta-yaml/digest-images-helper';
import { MetaYamlPluginInfo } from '../../src/meta-yaml/meta-yaml-plugin-info';
import { RegistryHelper } from '../../src/registry/registry-helper';

describe('Test DigestImagesHelper', () => {
  let container: Container;

  let metaYamlPlugins: MetaYamlPluginInfo[];
  let digestImagesHelper: DigestImagesHelper;

  const registryHelperGetImageDigestMock = jest.fn();
  const registryHelper: any = {
    getImageDigest: registryHelperGetImageDigestMock,
  };

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

    container.bind(DigestImagesHelper).toSelf().inSingletonScope();
    container.bind(RegistryHelper).toConstantValue(registryHelper);
    digestImagesHelper = container.get(DigestImagesHelper);
  });

  test('basics', async () => {
    registryHelperGetImageDigestMock.mockResolvedValueOnce('image-digest-1');
    registryHelperGetImageDigestMock.mockResolvedValueOnce('image-digest-2');
    registryHelperGetImageDigestMock.mockResolvedValueOnce('image-digest-3');
    registryHelperGetImageDigestMock.mockResolvedValueOnce('image-digest-4');

    const updatedYamls = await digestImagesHelper.updateImages(metaYamlPlugins);
    // only 4 images, so 4 calls
    expect(registryHelperGetImageDigestMock).toBeCalledTimes(4);

    const firstYaml = updatedYamls[0];
    expect((firstYaml.spec.containers as any)[0].image).toBe('image-digest-1');
    expect((firstYaml.spec.containers as any)[1].image).toBe('image-digest-2');
    expect((firstYaml.spec.initContainers as any)[0].image).toBe('image-digest-3');
    expect((firstYaml.spec.initContainers as any)[1].image).toBe('image-digest-4');
  });
});
