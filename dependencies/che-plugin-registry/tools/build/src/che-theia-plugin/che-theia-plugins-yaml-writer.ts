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
import * as jsyaml from 'js-yaml';
import * as path from 'path';

import { inject, injectable, named } from 'inversify';

import { CheTheiaPluginYamlInfo } from './che-theia-plugin-yaml-info';

@injectable()
export class CheTheiaPluginsYamlWriter {
  @inject('string')
  @named('OUTPUT_ROOT_DIRECTORY')
  private outputRootDirectory: string;

  @inject('boolean')
  @named('EMBED_VSIX')
  private embedVsix: boolean;

  // Path relative to plugin registry ROOT
  //    https://plugin-registry-eclipse-che.apps-crc.testing/v3
  //
  // It must work also for single root deployments
  //    https://che-eclipse-che.apps-crc.testing/plugin-registry/v3
  public static readonly DEFAULT_ICON = '/images/default.png';

  convertIdToPublisherAndName(id: string): [string, string] {
    const values = id.split('/');
    return [values[0], values[1]];
  }

  async write(cheTheiaPluginYamlInfos: CheTheiaPluginYamlInfo[]): Promise<void> {
    // now, write the files
    const pluginsFolder = path.resolve(this.outputRootDirectory, 'v3', 'plugins');
    await fs.ensureDir(pluginsFolder);
    const imagesFolder = path.resolve(this.outputRootDirectory, 'v3', 'images');
    await fs.ensureDir(imagesFolder);
    const resourcesFolder = path.resolve(this.outputRootDirectory, 'v3', 'resources');
    await fs.ensureDir(resourcesFolder);

    await Promise.all(
      cheTheiaPluginYamlInfos.map(async cheTheiaPluginYamlInfo => {
        const { aliases, data, vsixInfos } = cheTheiaPluginYamlInfo;
        const iconFile = data.metadata.iconFile;
        // write icon if iconfFile is specified or use default icon
        let icon: string;
        if (iconFile) {
          // write icon in v3/images folder
          const fileExtensionIcon = path.extname(path.basename(iconFile)).toLowerCase();
          const destIconFileName = `${data.metadata.publisher}-${data.metadata.name}-icon${fileExtensionIcon}`;
          await fs.copyFile(iconFile, path.resolve(imagesFolder, destIconFileName));
          icon = `/images/${destIconFileName}`;
        } else {
          icon = CheTheiaPluginsYamlWriter.DEFAULT_ICON;
        }

        // copy vsix for offline storage
        if (this.embedVsix) {
          // need to write vsix file downloaded
          await Promise.all(
            data.extensions.map(async (extension, index) => {
              const vsixInfo = vsixInfos.get(extension);
              if (vsixInfo && vsixInfo.downloadedArchive) {
                const directoryPattern = path
                  .dirname(extension)
                  .replace('http://', '')
                  .replace('https://', '')
                  .replace(/[^a-zA-Z0-9-/]/g, '_');
                const filePattern = path.basename(extension);
                const destFolder = path.join(resourcesFolder, directoryPattern);
                const destFile = path.join(destFolder, filePattern);
                await fs.ensureDir(destFolder);
                await fs.copyFile(vsixInfo.downloadedArchive, destFile);
                data.extensions[index] = `relative:extension/resources/${directoryPattern}/${filePattern}`;
              }
            })
          );
        }
        const promises: Promise<unknown>[] = [];
        // write content
        // const computedId = `${data.metadata.publisher}/${data.metadata.name}`;
        const convertedValue = this.convertIdToPublisherAndName(data.metadata.id);
        const generatedPublisher = convertedValue[0];
        const generatedName = convertedValue[1];

        // add spec object
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const writingData: any = {
          ...data,
        };
        writingData.metadata.icon = icon;
        delete writingData.metadata.iconFile;
        // remove undefined fields
        const newAliases = aliases || [];
        // add current name before all aliases
        newAliases.unshift(`${generatedPublisher}/${generatedName}`);
        newAliases.forEach(async alias => {
          const publisherAndName = this.convertIdToPublisherAndName(alias);
          const writingPublisher = publisherAndName[0];
          const writingName = publisherAndName[1];
          const writingId = `${writingPublisher}/${writingName}`;
          const cleanupWritingData = JSON.parse(JSON.stringify(writingData));
          cleanupWritingData.metadata.id = writingId;
          cleanupWritingData.metadata.publisher = writingPublisher;
          cleanupWritingData.metadata.name = writingName;
          cleanupWritingData.metadata.version = 'latest';
          const yamlString = jsyaml.safeDump(cleanupWritingData, { lineWidth: -1 });
          const pluginPath = path.resolve(pluginsFolder, alias, 'latest', 'che-theia-plugin.yaml');
          await fs.ensureDir(path.dirname(pluginPath));
          promises.push(fs.writeFile(pluginPath, yamlString));
        });
      })
    );
  }
}
