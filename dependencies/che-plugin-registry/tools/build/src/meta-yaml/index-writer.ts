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
 * Write in a file named index.json, all the plugins that can be found.
 */
@injectable()
export class IndexWriter {
  @inject('string')
  @named('OUTPUT_ROOT_DIRECTORY')
  private outputRootDirectory: string;

  getLinks(plugin: MetaYamlPluginInfo): { self: string; devfile?: string } {
    const links: { self: string; devfile?: string } = {
      self: `/v3/plugins/${plugin.id}`,
    };
    if (plugin.type === 'Che Editor' || plugin.type === 'Che Plugin') {
      links.devfile = `/v3/plugins/${plugin.id}/devfile.yaml`;
    }
    return links;
  }

  async write(generatedMetaYamlPluginInfos: MetaYamlPluginInfo[]): Promise<void> {
    const v3PluginsFolder = path.resolve(this.outputRootDirectory, 'v3', 'plugins');
    await fs.ensureDir(v3PluginsFolder);
    const externalImagesFile = path.join(v3PluginsFolder, 'index.json');

    const indexValues = generatedMetaYamlPluginInfos.map(plugin => ({
      id: plugin.id,
      description: plugin.description,
      displayName: plugin.displayName,
      links: this.getLinks(plugin),
      name: plugin.name,
      publisher: plugin.publisher,
      type: plugin.type,
      version: plugin.version,
    }));
    indexValues.sort((pluginA, pluginB) => pluginA.id.localeCompare(pluginB.id));
    await fs.writeFile(externalImagesFile, JSON.stringify(indexValues, undefined, 2));
  }
}
