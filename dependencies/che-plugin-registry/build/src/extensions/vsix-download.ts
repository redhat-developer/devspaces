/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
import * as fs from 'fs-extra';
import * as path from 'path';
import * as url from 'url';

import { inject, injectable, named } from 'inversify';

import Axios from 'axios';
import { VsixInfo } from './vsix-info';

/**
 * Handle download of a remote vsix
 * Note: only VsixUrlAnalyzer is able to run concurrently
 */
@injectable()
export class VsixDownload {
  @inject('string')
  @named('DOWNLOAD_ROOT_DIRECTORY')
  private downloadRootDirectory: string;

  async download(vsixInfo: VsixInfo): Promise<void> {
    const vsixUri = vsixInfo.uri;
    const link = url.parse(vsixUri);
    if (!link.pathname) {
      throw new Error('invalid link URI: ' + vsixUri);
    }
    const dirname = path.dirname(link.pathname);
    const basename = path.basename(link.pathname);
    const filename = dirname.replace(/\W/g, '_') + '-' + basename;
    const unpackedPath = path.resolve(this.downloadRootDirectory, path.basename(filename));
    // use of cache. If file is already there use it directly
    const pathExists = await fs.pathExists(unpackedPath);
    vsixInfo.downloadedArchive = unpackedPath;
    if (pathExists) {
      return;
    }
    const writer = fs.createWriteStream(unpackedPath);
    const response = await Axios.get(vsixUri, { responseType: 'stream' });
    response.data.pipe(writer);
    return new Promise<void>((resolve, reject) => {
      writer.on('finish', () => resolve());
      writer.on('error', error => reject(error));
    });
  }
}
