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

import * as fs from 'fs-extra';

import { Container } from 'inversify';
import { VsixInfo } from '../../src/extensions/vsix-info';
import { VsixReadInfo } from '../../src/extensions/vsix-read-info';
import { createVsixInfo } from './vsix-info-mock';

jest.mock('fs-extra');

describe('Test VsixReadInfo', () => {
  let container: Container;

  let vsixReadInfo: any;
  let vsixInfoToAnalyze: VsixInfo;

  beforeEach(() => {
    vsixInfoToAnalyze = createVsixInfo();
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind(VsixReadInfo).toSelf().inSingletonScope();
    vsixReadInfo = container.get(VsixReadInfo);
  });

  test('basics vsix', async () => {
    expect(vsixInfoToAnalyze.packageJson).toBeUndefined();
    vsixInfoToAnalyze.unpackedArchive = 'my-plugin.vsix';
    vsixInfoToAnalyze.unpackedExtensionRootDir = '/fake-root-dir';
    const pathExistSpy = jest.spyOn(fs, 'pathExists') as jest.Mock;
    pathExistSpy.mockResolvedValueOnce(true);

    // no nls file
    pathExistSpy.mockResolvedValueOnce(false);

    const jsonString = '{"activationEvents": ["my-activation1", "my-activation2"]}';
    const readFileSpy = jest.spyOn(fs, 'readFile') as jest.Mock;
    readFileSpy.mockResolvedValueOnce(jsonString);
    await vsixReadInfo.read(vsixInfoToAnalyze);
    expect(vsixInfoToAnalyze.packageJson).toBeDefined();
    expect((vsixInfoToAnalyze.packageJson as any).activationEvents).toStrictEqual(['my-activation1', 'my-activation2']);

    // two times
    expect(pathExistSpy).toBeCalledTimes(2);
    // no nls so one time
    expect(readFileSpy).toBeCalledTimes(1);
  });

  test('basics theia', async () => {
    expect(vsixInfoToAnalyze.packageJson).toBeUndefined();
    vsixInfoToAnalyze.unpackedArchive = 'my-plugin.theia';
    vsixInfoToAnalyze.unpackedExtensionRootDir = '/fake-root-dir';
    const pathExistSpy = jest.spyOn(fs, 'pathExists') as jest.Mock;
    pathExistSpy.mockResolvedValueOnce(true);

    // no nls file
    pathExistSpy.mockResolvedValueOnce(false);

    const jsonString = '{"activationEvents": ["my-activation1", "my-activation2"]}';
    const readFileSpy = jest.spyOn(fs, 'readFile') as jest.Mock;
    readFileSpy.mockResolvedValueOnce(jsonString);
    await vsixReadInfo.read(vsixInfoToAnalyze);
    expect(vsixInfoToAnalyze.packageJson).toBeDefined();
    expect((vsixInfoToAnalyze.packageJson as any).activationEvents).toStrictEqual(['my-activation1', 'my-activation2']);

    // only once
    expect(readFileSpy).toBeCalledTimes(1);
    expect(pathExistSpy).toBeCalledTimes(1);
  });

  test('basics with nls', async () => {
    expect(vsixInfoToAnalyze.packageJson).toBeUndefined();
    vsixInfoToAnalyze.unpackedArchive = 'my-plugin.vsix';
    vsixInfoToAnalyze.unpackedExtensionRootDir = '/fake-root-dir';
    const pathExistSpy = jest.spyOn(fs, 'pathExists') as jest.Mock;
    pathExistSpy.mockResolvedValueOnce(true);

    // there is nls file
    pathExistSpy.mockResolvedValueOnce(true);

    const jsonString = '{"activationEvents": ["my-activation1", "my-activation2"]}';
    const readFileSpy = jest.spyOn(fs, 'readFile') as jest.Mock;
    readFileSpy.mockResolvedValueOnce(jsonString);

    // nls read
    const nlsJson = { property: 'value' };
    readFileSpy.mockResolvedValueOnce(JSON.stringify(nlsJson));

    await vsixReadInfo.read(vsixInfoToAnalyze);
    expect(vsixInfoToAnalyze.packageJson).toBeDefined();
    expect((vsixInfoToAnalyze.packageJson as any).activationEvents).toStrictEqual(['my-activation1', 'my-activation2']);
    expect(vsixInfoToAnalyze.packageNlsJson).toStrictEqual(nlsJson);

    // two times
    expect(pathExistSpy).toBeCalledTimes(2);
    // nls so two times
    expect(readFileSpy).toBeCalledTimes(2);
  });

  test('path does not exists', async () => {
    expect(vsixInfoToAnalyze.packageJson).toBeUndefined();
    vsixInfoToAnalyze.unpackedArchive = 'my-plugin.theia';
    vsixInfoToAnalyze.unpackedExtensionRootDir = '/fake-root-dir';

    const pathExistSpy = jest.spyOn(fs, 'pathExists') as jest.Mock;
    pathExistSpy.mockResolvedValue(false);
    await expect(vsixReadInfo.read(vsixInfoToAnalyze)).rejects.toThrow(
      `Unable to find package.json file from vsix ${vsixInfoToAnalyze.uri}`
    );
  });

  test('missing unpackedExtensionRootDir', async () => {
    vsixInfoToAnalyze.unpackedArchive = '.foo';

    await expect(vsixReadInfo.read(vsixInfoToAnalyze)).rejects.toThrow(
      "Cannot read something in unpacked vsix as it's not unpacked correctly."
    );
  });

  test('not unpacked', async () => {
    await expect(vsixReadInfo.read(vsixInfoToAnalyze)).rejects.toThrow(
      "Cannot read something in unpacked vsix as it's not unpacked."
    );
  });
});
