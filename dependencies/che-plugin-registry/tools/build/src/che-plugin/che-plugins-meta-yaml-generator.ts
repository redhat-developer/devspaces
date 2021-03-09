/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/

import { inject, injectable } from 'inversify';

import { ChePluginMetaInfo } from './che-plugins-meta-info';
import { MetaYamlPluginInfo } from '../meta-yaml/meta-yaml-plugin-info';
import { VolumeMountHelper } from '../common/volume-mount-helper';

@injectable()
export class ChePluginsMetaYamlGenerator {
  @inject(VolumeMountHelper)
  private volumeMountHelper: VolumeMountHelper;

  async compute(chePlugins: ChePluginMetaInfo[]): Promise<MetaYamlPluginInfo[]> {
    // for each plugin, compute info
    const metaYamlPluginInfos: MetaYamlPluginInfo[] = await Promise.all(
      chePlugins.map(async (chePlugin: ChePluginMetaInfo) => {
        const type = 'Che Plugin';
        const chePluginOutput = JSON.stringify(chePlugin);

        const id = chePlugin.id;
        const splitIds = id.split('/');
        if (splitIds.length !== 3) {
          throw new Error(`The id for ${chePluginOutput} is not composed of 3 parts separated by / like <1>/<2>/<3>`);
        }
        const publisher = splitIds[0];
        const name = splitIds[1];
        const metaId = `${publisher}/${name}`;
        const version = splitIds[2];
        let disableLatest: boolean;
        // disable latest alias if version is not a number (probably like next/nightly/etc.)
        if (!Number.isInteger(parseInt(version[0]))) {
          disableLatest = true;
        } else {
          disableLatest = false;
        }
        const displayName = chePlugin.displayName;
        const title = chePlugin.displayName;
        const description = chePlugin.description;
        const category = 'Other';
        const iconFile = chePlugin.iconFile;
        const repository = chePlugin.repository;
        const firstPublicationDate = chePlugin.firstPublicationDate;

        const latestUpdateDate = new Date().toISOString().slice(0, 10);
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const spec: any = {};
        if (chePlugin.endpoints) {
          spec.endpoints = chePlugin.endpoints;
        }
        if (chePlugin.containers) {
          spec.containers = chePlugin.containers.map(container => this.volumeMountHelper.resolve(container));
        }
        if (chePlugin.initContainers) {
          spec.initContainers = chePlugin.initContainers.map(container => this.volumeMountHelper.resolve(container));
        }

        return {
          id: metaId,
          publisher,
          disableLatest,
          name,
          version,
          type,
          displayName,
          title,
          description,
          iconFile,
          repository,
          category,
          firstPublicationDate,
          latestUpdateDate,
          spec,
        } as MetaYamlPluginInfo;
      })
    );

    return metaYamlPluginInfos;
  }
}
