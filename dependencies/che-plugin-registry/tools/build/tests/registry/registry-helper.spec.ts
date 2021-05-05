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

import * as crypto from 'crypto';

import Axios from 'axios';
import { Container } from 'inversify';
import { RegistryHelper } from '../../src/registry/registry-helper';
import { parse } from 'docker-image-name-parser';
import simpleGit from 'simple-git';

jest.unmock('axios');
const git = simpleGit({ maxConcurrentProcesses: 1 });

describe('Test RegistryHelper', () => {
  let container: Container;

  let registryHelper: RegistryHelper;

  beforeAll(() => {
    container = new Container();
    container.bind(RegistryHelper).toSelf().inSingletonScope();
    registryHelper = container.get(RegistryHelper);
  });

  beforeEach(() => {
    jest.restoreAllMocks();
    jest.resetAllMocks();
  });

  test('parser full', async () => {
    const image = parse('quay.io/eclipse/foo:tag');
    expect(image.host).toBe('quay.io');
    expect(image.remoteName).toBe('eclipse/foo');
    expect(image.tag).toBe('tag');
  });

  test('parser full no tag', async () => {
    const image = parse('quay.io/eclipse/foo');
    expect(image.host).toBe('quay.io');
    expect(image.remoteName).toBe('eclipse/foo');
    expect(image.tag).toBe('latest');
  });

  test('parser partial', async () => {
    const image = parse('eclipse/foo');
    expect(image.host).toBe('index.docker.io');
    expect(image.remoteName).toBe('eclipse/foo');
    expect(image.tag).toBe('latest');
  });

  test('parser library', async () => {
    const image = parse('alpine');
    expect(image.host).toBe('index.docker.io');
    expect(image.remoteName).toBe('library/alpine');
    expect(image.tag).toBe('latest');
  });

  test('parser library/tag', async () => {
    const image = parse('alpine:3.12');
    expect(image.host).toBe('index.docker.io');
    expect(image.remoteName).toBe('library/alpine');
    expect(image.tag).toBe('3.12');
  });

  test('basics', async () => {
    const content = 'foobar-content';
    const hash = crypto.createHash('sha256').update(content).digest('hex');

    const response = {
      data: content,
    };
    const axiosGet = jest.spyOn(Axios, 'get') as jest.Mock;
    axiosGet.mockResolvedValueOnce(response);

    const axiosHead = jest.spyOn(Axios, 'head') as jest.Mock;
    axiosHead.mockResolvedValueOnce('');
    const digest = await registryHelper.getImageDigest('fake-docker-registry.com/dummy-org/dummy-image:1.2.3');
    expect(digest).toBe(`fake-docker-registry.com/dummy-org/dummy-image@sha256:${hash}`);
  });

  test('basics with docker.io', async () => {
    const content = 'foobar-content';
    const token = '1234';
    const hash = crypto.createHash('sha256').update(content).digest('hex');

    const tokenResponse = {
      data: { token },
    };

    const response = {
      data: content,
    };
    const axiosGet = jest.spyOn(Axios, 'get') as jest.Mock;

    // docker.io so need a token
    axiosGet.mockResolvedValueOnce(tokenResponse);
    axiosGet.mockResolvedValueOnce(response);

    const axiosHead = jest.spyOn(Axios, 'head') as jest.Mock;
    axiosHead.mockResolvedValueOnce('');
    const digest = await registryHelper.getImageDigest('docker.io/alpine:3.13.0');

    // image should have library as prefix as well and index.docker.io as host
    expect(digest).toBe(`index.docker.io/library/alpine@sha256:${hash}`);
  });

  test('basics with next', async () => {
    const axiosGet = jest.spyOn(Axios, 'get') as jest.Mock;
    const imageName = 'fake-docker-registry.com/dummy-org/dummy-image:next';
    const axiosHead = jest.spyOn(Axios, 'head') as jest.Mock;
    const updatedImageName = await registryHelper.getImageDigest('fake-docker-registry.com/dummy-org/dummy-image:next');
    expect(updatedImageName).toBe(imageName);
    expect(axiosGet).toBeCalledTimes(0);
    expect(axiosHead).toBeCalledTimes(0);
  });

  test('basics with current sha1', async () => {
    const gitRootDirectory = await git.revparse(['--show-toplevel']);
    const logOptions = {
      format: { hash: '%H' },
      file: gitRootDirectory,
      // keep only one result
      n: '1',
    };
    const result = await git.log(logOptions);
    const latest = result.latest;
    if (!latest) {
      throw new Error(`Unable to find result when executing ${JSON.stringify(logOptions)}`);
    }
    const hash = latest.hash;
    const shortSha1 = hash.substring(0, 7);

    const axiosGet = jest.spyOn(Axios, 'get') as jest.Mock;
    const imageName = `fake-docker-registry.com/dummy-org/dummy-image:go-${shortSha1}`;
    const axiosHead = jest.spyOn(Axios, 'head') as jest.Mock;
    const updatedImageName = await registryHelper.getImageDigest(imageName);
    expect(updatedImageName).toBe(imageName);
    expect(axiosGet).toBeCalledTimes(0);
    expect(axiosHead).toBeCalledTimes(0);
  });
});
