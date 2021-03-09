/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
import * as decompress from 'decompress';
import * as fs from 'fs-extra';
import * as path from 'path';

import { inject, injectable, named } from 'inversify';

import { VsixInfo } from './vsix-info';

/**
 * Unpack a given archive
 * Note: only VsixUrlAnalyzer is able to run 'concurrently'
 */
@injectable()
export class VsixUnpack {
  @inject('string')
  @named('UNPACKED_ROOT_DIRECTORY')
  private unpackedRootDirectory: string;

  async updateIconInfo(rootDir: string, vsixInfo: VsixInfo): Promise<void> {
    const packageJsonPath = path.resolve(rootDir, 'package.json');
    const statsFile = await fs.stat(packageJsonPath);
    vsixInfo.creationDate = statsFile.mtime.toISOString().slice(0, 10);
  }

  async unpack(vsixInfo: VsixInfo): Promise<void> {
    if (!vsixInfo.downloadedArchive) {
      throw new Error('Cannot unpack a vsix as it is not yet downloaded.');
    }
    const destFolder = path.resolve(this.unpackedRootDirectory, path.basename(vsixInfo.uri));
    // use of cache. If file is already there use it directly
    vsixInfo.unpackedArchive = destFolder;

    let rootDir: string;
    if (vsixInfo.uri.endsWith('.vsix')) {
      rootDir = path.resolve(destFolder, 'extension');
    } else if (vsixInfo.uri.endsWith('.theia')) {
      rootDir = path.resolve(destFolder);
    } else {
      throw new Error(`Unknown URI format for uri ${vsixInfo.uri}`);
    }

    vsixInfo.unpackedExtensionRootDir = rootDir;
    const pathExists = await fs.pathExists(destFolder);
    if (pathExists) {
      this.updateIconInfo(rootDir, vsixInfo);
      return;
    }
    await decompress(vsixInfo.downloadedArchive, destFolder);
    this.updateIconInfo(rootDir, vsixInfo);
  }
}
