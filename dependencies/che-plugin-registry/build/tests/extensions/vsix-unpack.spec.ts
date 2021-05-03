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

import * as decompress from 'decompress';
import * as fs from 'fs-extra';

import { Container } from 'inversify';
import { VsixInfo } from '../../src/extensions/vsix-info';
import { VsixUnpack } from '../../src/extensions/vsix-unpack';
import { createVsixInfo } from './vsix-info-mock';

/* eslint-disable @typescript-eslint/no-explicit-any */

jest.mock('fs-extra');
jest.mock('decompress');

describe('Test VsixUnpack', () => {
  let container: Container;

  let vsixUnpack: any;
  let vsixInfoToAnalyze: VsixInfo;

  beforeEach(() => {
    vsixInfoToAnalyze = createVsixInfo();
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind('string').toConstantValue('/foo-unpack').whenTargetNamed('UNPACKED_ROOT_DIRECTORY');
    container.bind(VsixUnpack).toSelf().inSingletonScope();
    vsixUnpack = container.get(VsixUnpack);
  });

  test('basics vsix', async () => {
    const downloadedArchiveName = '/tmp/my-plugin.vsix';
    const unpackedDirShouldBe = '/foo-unpack/my-fake.vsix';
    expect(vsixInfoToAnalyze.unpackedArchive).toBeUndefined();
    vsixInfoToAnalyze.downloadedArchive = downloadedArchiveName;

    const pathExistSpy = jest.spyOn(fs, 'pathExists') as jest.Mock;
    pathExistSpy.mockResolvedValue(false);

    const statSpy = jest.spyOn(fs, 'stat') as jest.Mock;
    statSpy.mockResolvedValue({ mtime: new Date() });

    await vsixUnpack.unpack(vsixInfoToAnalyze);
    expect(vsixInfoToAnalyze.unpackedArchive).toBe(unpackedDirShouldBe);
    expect(decompress).toBeCalled();
    const call = (decompress as jest.Mock).mock.calls[0];
    expect(call[0]).toBe(downloadedArchiveName);
    expect(call[1]).toBe(unpackedDirShouldBe);
  });

  test('basics theia', async () => {
    vsixInfoToAnalyze.uri = 'my-fake-plugin.theia';
    const downloadedArchiveName = '/fake/my-fake-plugin.theia';
    const unpackedDirShouldBe = '/foo-unpack/my-fake-plugin.theia';
    expect(vsixInfoToAnalyze.unpackedArchive).toBeUndefined();
    vsixInfoToAnalyze.downloadedArchive = downloadedArchiveName;

    const pathExistSpy = jest.spyOn(fs, 'pathExists') as jest.Mock;
    pathExistSpy.mockResolvedValue(false);

    const statSpy = jest.spyOn(fs, 'stat') as jest.Mock;
    statSpy.mockResolvedValue({ mtime: new Date() });

    await vsixUnpack.unpack(vsixInfoToAnalyze);
    expect(vsixInfoToAnalyze.unpackedArchive).toBe(unpackedDirShouldBe);
    expect(decompress).toBeCalled();
    const call = (decompress as jest.Mock).mock.calls[0];
    expect(call[0]).toBe(downloadedArchiveName);
    expect(call[1]).toBe(unpackedDirShouldBe);
  });

  test('already downloaded', async () => {
    vsixInfoToAnalyze.downloadedArchive = 'my-plugin.theia';

    const pathExistSpy = jest.spyOn(fs, 'pathExists') as jest.Mock;
    pathExistSpy.mockResolvedValue(true);
    const statSpy = jest.spyOn(fs, 'stat') as jest.Mock;
    statSpy.mockResolvedValue({ mtime: new Date() });
    await vsixUnpack.unpack(vsixInfoToAnalyze);
    expect(decompress).toBeCalledTimes(0);
  });

  test('not unpacked', async () => {
    await expect(vsixUnpack.unpack(vsixInfoToAnalyze)).rejects.toThrow(
      'Cannot unpack a vsix as it is not yet downloaded.'
    );
  });

  test('not a vsix or theia plugin', async () => {
    vsixInfoToAnalyze.uri = 'my-fake-plugin.unknown';
    const downloadedArchiveName = '/fake/my-fake-plugin.unknown';
    expect(vsixInfoToAnalyze.unpackedArchive).toBeUndefined();
    vsixInfoToAnalyze.downloadedArchive = downloadedArchiveName;

    await expect(vsixUnpack.unpack(vsixInfoToAnalyze)).rejects.toThrow(
      `Unknown URI format for uri ${vsixInfoToAnalyze.uri}`
    );
  });
});
