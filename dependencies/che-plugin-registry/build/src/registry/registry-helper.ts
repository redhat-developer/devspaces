/**********************************************************************
 * Copyright (c) 2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/

import * as crypto from 'crypto';

import { injectable, postConstruct } from 'inversify';
import simpleGit, { SimpleGit } from 'simple-git';

import Axios from 'axios';
import { parse } from 'docker-image-name-parser';

/**
 * Allow to grab information from docker.io and quay.io
 */
@injectable()
export class RegistryHelper {
  private shortSha1: string;
  private git: SimpleGit;

  constructor() {
    // reduce concurrent processes
    this.git = simpleGit({ maxConcurrentProcesses: 1 });
  }

  @postConstruct()
  async init(): Promise<void> {
    const gitRootDirectory = await this.git.revparse(['--show-toplevel']);
    const logOptions = {
      format: { hash: '%H' },
      file: gitRootDirectory,
      // keep only one result
      n: '1',
    };
    const result = await this.git.log(logOptions);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const hash = (result.latest as any).hash;
    this.shortSha1 = hash.substring(0, 7);
  }

  async getImageDigest(imageName: string): Promise<string> {
    if (imageName.startsWith('docker.io')) {
      imageName = imageName.replace('docker.io', 'index.docker.io');
    }
    // grab image name and tag
    const dockerImageName = parse(imageName);

    // do not use digest on nightlies/next
    if (dockerImageName.tag === 'nightly' || dockerImageName.tag === 'next') {
      return imageName;
    }
    // do not grab digest of an image that is being published (if tag contains the current sha1)
    if (dockerImageName.tag && dockerImageName.tag.includes(this.shortSha1)) {
      console.log(
        `Do not fetch digest for ${imageName} as the tag ${dockerImageName.tag} includes the current sha1 ${this.shortSha1}`
      );
      return imageName;
    }

    const uri = `https://${dockerImageName.host}/v2/${dockerImageName.remoteName}/manifests/${dockerImageName.tag}`;

    // if registry is [index.]docker.io, need to grab a token first
    let token;
    if (dockerImageName.host === 'index.docker.io') {
      const tokenUri = `https://auth.docker.io/token?service=registry.docker.io&scope=repository:${dockerImageName.remoteName}:pull`;
      const tokenResponse = await Axios.get(tokenUri, {
        headers: {
          Accept:
            'application/vnd.docker.distribution.manifest.v2+json,application/vnd.docker.distribution.manifest.list.v2+json',
        },
        responseType: 'json',
      });

      token = tokenResponse.data.token;
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const headers = {} as any;

    // use a token if required
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    // use custom headers to correctly grab all information
    headers['Accept'] =
      'application/vnd.docker.distribution.manifest.v2+json,application/vnd.docker.distribution.manifest.list.v2+json';

    // to workaround that JSON is tried on response even if text is specified, use arraybuffer instead
    // we really need untouched raw content as we're using content to apply sha256 on it
    // https://github.com/axios/axios/issues/907
    const response = await Axios.get(uri, {
      headers,
      responseType: 'arraybuffer',
    });

    // hash raw content returned
    const content = Buffer.from(response.data, 'binary').toString();
    const hash = crypto.createHash('sha256').update(content).digest('hex');

    // verify this digest exists
    const verifyUri = `https://${dockerImageName.host}/v2/${dockerImageName.remoteName}/manifests/sha256:${hash}`;

    // if digest is not here it'll throw an error
    await Axios.head(verifyUri, {
      headers,
      responseType: 'arraybuffer',
    });
    return `${dockerImageName.host}/${dockerImageName.remoteName}@sha256:${hash}`;
  }
}
