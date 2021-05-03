/**********************************************************************
 * Copyright (c) 2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/

import * as fs from 'fs-extra';
import * as path from 'path';

import { inject, injectable, named } from 'inversify';

import { MetaYamlPluginInfo } from './meta-yaml-plugin-info';

/**
 * Write in a file named external_images.txt, all the images referenced by plug-ins.
 */
@injectable()
export class ExternalImagesWriter {
  @inject('string')
  @named('OUTPUT_ROOT_DIRECTORY')
  private outputRootDirectory: string;

  async write(metaYamlPluginInfos: MetaYamlPluginInfo[]): Promise<void> {
    const v3Folder = path.resolve(this.outputRootDirectory, 'v3');
    await fs.ensureDir(v3Folder);
    const externalImagesFile = path.join(v3Folder, 'external_images.txt');

    const referencedImages = metaYamlPluginInfos
      .map(plugin => {
        const images = [];
        const spec = plugin.spec;
        if (spec) {
          if (spec.containers) {
            images.push(...spec.containers.map(container => container.image));
          }
          if (spec.initContainers) {
            images.push(...spec.initContainers.map(initContainer => initContainer.image));
          }
        }
        return images;
      })
      // flatten array of array into a single array
      .reduce((previousValue, currentValue) => previousValue.concat(currentValue), []);

    // now, write the file
    await fs.writeFile(externalImagesFile, referencedImages.join('\n'));
  }
}
