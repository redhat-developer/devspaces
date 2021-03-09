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
/* eslint-disable @typescript-eslint/no-non-null-assertion */
import 'reflect-metadata';

import { ContainerVolumeMounts, VolumeMountHelper } from '../../src/common/volume-mount-helper';

import { Container } from 'inversify';

describe('Test VolumeMountHelper', () => {
  let volumeMountHelper: VolumeMountHelper;
  let container: Container;

  beforeEach(() => {
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind('string').toConstantValue('/fake-output').whenTargetNamed('OUTPUT_ROOT_DIRECTORY');

    container.bind(VolumeMountHelper).toSelf().inSingletonScope();
    volumeMountHelper = container.get(VolumeMountHelper);
  });

  test('basics', async () => {
    const containerVolumes: ContainerVolumeMounts = {
      volumeMounts: [
        {
          ephemeral: true,
          name: 'example',
          path: '/foo',
        },
        {
          name: 'example2',
          path: '/bar',
        },
      ],
    };
    const containerVolume = await volumeMountHelper.resolve(containerVolumes);
    expect(containerVolume).toBeDefined();
    expect(containerVolume.volumes).toBeDefined();
    const volumes = containerVolume.volumes!;
    expect(volumes[0].ephemeral).toBe(true);
    expect(volumes[0].mountPath).toBe('/foo');
    expect(volumes[0].name).toBe('example');
    expect(volumes[1].ephemeral).toBeUndefined();
    expect(volumes[1].mountPath).toBe('/bar');
    expect(volumes[1].name).toBe('example2');
  });

  test('empty', async () => {
    const containerVolumes: ContainerVolumeMounts = {};
    const containerVolume = await volumeMountHelper.resolve(containerVolumes);
    expect(containerVolume).toBeDefined();
    expect(containerVolume.volumes).toBeUndefined();
  });
});
