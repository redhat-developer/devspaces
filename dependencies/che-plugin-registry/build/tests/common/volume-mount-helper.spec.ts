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

import { CheEditorContainerYaml } from '../../src/editor/che-editors-yaml';
import { Container } from 'inversify';
import { VolumeMountHelper } from '../../src/common/volume-mount-helper';

describe('Test VolumeMountHelper', () => {
  let volumeMountHelper: VolumeMountHelper;
  let container: Container;

  let containerVolumeMounts: CheEditorContainerYaml;

  beforeEach(() => {
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind('string').toConstantValue('/fake-output').whenTargetNamed('OUTPUT_ROOT_DIRECTORY');

    containerVolumeMounts = {
      image: 'image',
      volumeMounts: [
        {
          name: 'example',
          path: '/foo',
        },
        {
          name: 'example2',
          path: '/bar',
        },
      ],
    };

    container.bind(VolumeMountHelper).toSelf().inSingletonScope();
    volumeMountHelper = container.get(VolumeMountHelper);
  });

  test('basics', async () => {
    const volumes = new Map();
    volumes.set('example', { ephemeral: true });
    const containerVolume = await volumeMountHelper.resolve(containerVolumeMounts, volumes);
    expect(containerVolume).toBeDefined();
    expect(containerVolume.volumes).toBeDefined();
    const volumeMount = containerVolume.volumes!;
    expect(volumeMount[0].ephemeral).toBe(true);
    expect(volumeMount[0].mountPath).toBe('/foo');
    expect(volumeMount[0].name).toBe('example');
    expect(volumeMount[1].ephemeral).toBeUndefined();
    expect(volumeMount[1].mountPath).toBe('/bar');
    expect(volumeMount[1].name).toBe('example2');
  });

  test('empty', async () => {
    const containerVolume = await volumeMountHelper.resolve({ image: 'image' });
    expect(containerVolume).toBeDefined();
    expect(containerVolume.volumes).toBeUndefined();
  });

  test('empty volumes', async () => {
    const containerVolume = await volumeMountHelper.resolve(containerVolumeMounts);
    expect(containerVolume).toBeDefined();
    expect(containerVolume.volumes).toBeDefined();
    const volumeMount = containerVolume.volumes!;
    expect(volumeMount[0].ephemeral).toBeUndefined();
    expect(volumeMount[1].ephemeral).toBeUndefined();
  });
});
