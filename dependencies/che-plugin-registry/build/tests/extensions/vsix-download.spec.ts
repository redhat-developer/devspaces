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

import * as fs from 'fs-extra';

import Axios from 'axios';
import { Container } from 'inversify';
import { VsixDownload } from '../../src/extensions/vsix-download';
import { VsixInfo } from '../../src/extensions/vsix-info';
import { createVsixInfo } from './vsix-info-mock';

/* eslint-disable @typescript-eslint/no-explicit-any */

jest.mock('fs-extra');

describe('Test VsixDownload', () => {
  let container: Container;
  let vsixInfoToAnalyze: VsixInfo;
  const onErrorMessage = 'onErrorMessage';
  const events: Map<any, any> = new Map();
  const writer = {
    on(event: any, func: any): any {
      events.set(event, func);
      return this;
    },
    emit(event: any): void {
      let params = undefined;
      if (event === 'error') {
        params = onErrorMessage;
      }
      events.get(event)(params);
    },
  };
  let vsixDownload: any;

  beforeEach(() => {
    vsixInfoToAnalyze = createVsixInfo();
    events.clear();
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind('string').toConstantValue('foo').whenTargetNamed('DOWNLOAD_ROOT_DIRECTORY');
    container.bind(VsixDownload).toSelf().inSingletonScope();
    vsixDownload = container.get(VsixDownload);
  });

  test('basics', async () => {
    const pathExistSpy = jest.spyOn(fs, 'pathExists') as jest.Mock;
    const createWriteStreamSpy = jest.spyOn(fs, 'createWriteStream') as jest.Mock;
    pathExistSpy.mockResolvedValue(false);
    createWriteStreamSpy.mockReturnValue(writer);
    const pipeMethod = jest.fn();
    const response = {
      data: {
        pipe: pipeMethod,
      },
    };
    const axiosGet = jest.spyOn(Axios, 'get') as jest.Mock;
    axiosGet.mockResolvedValue(response);
    const promise = vsixDownload.download(vsixInfoToAnalyze);
    // Emit the finish event async
    setTimeout(() => {
      writer.emit('finish');
    }, 0);

    await promise;
    expect(pipeMethod).toBeCalled();
  });

  test('error fetch', async () => {
    const pathExistSpy = jest.spyOn(fs, 'pathExists') as jest.Mock;
    const createWriteStreamSpy = jest.spyOn(fs, 'createWriteStream') as jest.Mock;
    pathExistSpy.mockResolvedValue(false);
    createWriteStreamSpy.mockReturnValue(writer);
    const pipeMethod = jest.fn();
    const response = {
      data: {
        pipe: pipeMethod,
      },
    };
    const axiosGet = jest.spyOn(Axios, 'get') as jest.Mock;
    axiosGet.mockResolvedValue(response);
    const promise = vsixDownload.download(vsixInfoToAnalyze);
    // Emit the finish event async
    setTimeout(() => {
      writer.emit('error');
    }, 200);
    await expect(promise).rejects.toEqual('onErrorMessage');
  });

  test('path already exists', async () => {
    const pathExistSpy = jest.spyOn(fs, 'pathExists') as jest.Mock;
    const createWriteStreamSpy = jest.spyOn(fs, 'createWriteStream') as jest.Mock;
    pathExistSpy.mockResolvedValue(true);
    await vsixDownload.download(vsixInfoToAnalyze);
    expect(createWriteStreamSpy).toBeCalledTimes(0);
  });

  test('invalid uri', async () => {
    vsixInfoToAnalyze.uri = 'invalid:?&';
    await expect(vsixDownload.download(vsixInfoToAnalyze)).rejects.toThrow('invalid link URI: invalid:?&');
  });
});
