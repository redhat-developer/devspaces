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
import { VsixDownload } from '../../src/extensions/vsix-download';
import { VsixInfo } from '../../src/extensions/vsix-info';
import { VsixReadInfo } from '../../src/extensions/vsix-read-info';
import { VsixUnpack } from '../../src/extensions/vsix-unpack';
import { VsixUrlAnalyzer } from '../../src/extensions/vsix-url-analyzer';
import { createVsixInfo } from './vsix-info-mock';

jest.mock('fs-extra');

describe('Test VsixUrlAnalyzer', () => {
  let container: Container;

  const vsixDownloadMock = jest.fn();
  const vsixDownload: any = {
    download: vsixDownloadMock,
  };

  const vsixUnpackMock = jest.fn();
  const vsixUnpack: any = {
    unpack: vsixUnpackMock,
  };

  const vsixReadInfo: any = {
    read: jest.fn(),
  };
  let vsixUrlAnalyzer: any;
  let vsixInfoToAnalyze: VsixInfo;

  beforeEach(() => {
    vsixInfoToAnalyze = createVsixInfo();
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind(VsixDownload).toConstantValue(vsixDownload);
    container.bind(VsixReadInfo).toConstantValue(vsixReadInfo);
    container.bind(VsixUnpack).toConstantValue(vsixUnpack);
    container.bind(VsixUrlAnalyzer).toSelf().inSingletonScope();
    vsixUrlAnalyzer = container.get(VsixUrlAnalyzer);
  });

  test('basics', async () => {
    await vsixUrlAnalyzer.analyze(vsixInfoToAnalyze);
    expect(vsixDownload.download).toBeCalled();
    expect(vsixUnpack.unpack).toBeCalled();
    expect(vsixReadInfo.read).toBeCalled();
  });

  test('basics multiple calls', async () => {
    const longRunningJob = new Promise(resolve => {
      setTimeout(() => {
        resolve(true);
      }, 3000);
    });

    // make first download very long
    vsixDownloadMock.mockResolvedValueOnce(longRunningJob);
    vsixDownloadMock.mockResolvedValueOnce(Promise.resolve('fast'));

    // call two times
    const call1Promise = vsixUrlAnalyzer.analyze(vsixInfoToAnalyze);
    const call2Promise = vsixUrlAnalyzer.analyze(vsixInfoToAnalyze);

    // but it is stuck on download and only let one call pass
    expect(vsixDownload.download).toBeCalledTimes(1);
    expect(vsixUnpack.unpack).toBeCalledTimes(0);
    expect(vsixReadInfo.read).toBeCalledTimes(0);

    await call1Promise;
    await call2Promise;
    // two calls have been done sequentially
    expect(vsixDownload.download).toBeCalledTimes(2);
    expect(vsixUnpack.unpack).toBeCalledTimes(2);
    expect(vsixReadInfo.read).toBeCalledTimes(2);
  });
});
