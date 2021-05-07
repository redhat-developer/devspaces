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

import { VsixInfo } from './vsix-info';
import { injectable } from 'inversify';

/* eslint-disable @typescript-eslint/no-explicit-any */

/**
 * Read info from a vsix.
 */
@injectable()
export class VsixReadInfo {
  async read(vsixInfo: VsixInfo): Promise<void> {
    if (!vsixInfo.unpackedArchive) {
      throw new Error("Cannot read something in unpacked vsix as it's not unpacked.");
    }

    // theia plugin or vscode vsix ?
    if (!vsixInfo.unpackedExtensionRootDir) {
      throw new Error("Cannot read something in unpacked vsix as it's not unpacked correctly.");
    }
    const packageJsonPath = path.resolve(vsixInfo.unpackedExtensionRootDir, 'package.json');

    // read package.json which is in extension folder
    const exists = await fs.pathExists(packageJsonPath);
    if (!exists) {
      throw new Error(`Unable to find package.json file from vsix ${vsixInfo.uri}`);
    }
    const content = await fs.readFile(packageJsonPath, 'utf-8');
    vsixInfo.packageJson = JSON.parse(content);

    // read optional nls.json if present
    if (vsixInfo.unpackedArchive.endsWith('.vsix')) {
      const packageNlsJsonPath = path.resolve(vsixInfo.unpackedArchive, 'extension', 'package.nls.json');

      // read package.nls.json which is in extension folder
      const existsNlsFile = await fs.pathExists(packageNlsJsonPath);
      if (existsNlsFile) {
        const contentNls = await fs.readFile(packageNlsJsonPath, 'utf-8');
        vsixInfo.packageNlsJson = JSON.parse(contentNls);
      }
    }
  }
}
