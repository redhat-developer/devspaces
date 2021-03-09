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

import { Container } from 'inversify';
import { Sidecar } from '../../src/sidecar/sidecar';
import { SidecarDockerImage } from '../../src/sidecar/sidecar-docker-image';

describe('Test Sidecar', () => {
  let container: Container;

  const sidecarDockerImageGetDockerImageForMock = jest.fn();
  const sidecarDockerImage: any = {
    getDockerImageFor: sidecarDockerImageGetDockerImageForMock,
  };

  let sidecar: Sidecar;

  beforeEach(() => {
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind(Sidecar).toSelf().inSingletonScope();
    container.bind(SidecarDockerImage).toConstantValue(sidecarDockerImage);
    sidecar = container.get(Sidecar);
  });

  test('basics directory', async () => {
    const fakeImage = 'sidecar-image';
    const directory = 'my-sidecar-directory';
    // with directory, should return the image provided by the sidecarDockerImage component
    sidecarDockerImageGetDockerImageForMock.mockResolvedValue(fakeImage);
    const cheTheiaPluginMetaInfo: any = { sidecar: { directory } };
    const result = await sidecar.getDockerImageFor(cheTheiaPluginMetaInfo);
    expect(result).toBe(fakeImage);

    // should have called the component with the directory of the plugin
    expect(sidecarDockerImageGetDockerImageForMock).toBeCalled();
    expect(sidecarDockerImageGetDockerImageForMock.mock.calls[0][0]).toBe(directory);
  });

  test('basics image', async () => {
    // with image, should return the image field
    const image = 'foo';
    const cheTheiaPluginMetaInfo: any = { sidecar: { image } };
    const result = await sidecar.getDockerImageFor(cheTheiaPluginMetaInfo);
    expect(result).toBe(image);
  });

  test('no sidecar', async () => {
    const cheTheiaPluginMetaInfo: any = {};
    const result = await sidecar.getDockerImageFor(cheTheiaPluginMetaInfo);
    expect(result).toBeUndefined();
  });
});
