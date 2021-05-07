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

import { CheEditorMetaInfo } from './che-editors-meta-info';
import { ContainerHelper } from '../common/container-helper';
import { EndpointsHelper } from '../common/endpoints-helper';
import { MetaYamlPluginInfo } from '../meta-yaml/meta-yaml-plugin-info';

@injectable()
export class CheEditorsMetaYamlGenerator {
  @inject(EndpointsHelper)
  private endpointsHelper: EndpointsHelper;

  @inject(ContainerHelper)
  private containerHelper: ContainerHelper;

  async compute(cheEditors: CheEditorMetaInfo[]): Promise<MetaYamlPluginInfo[]> {
    // for each plugin, compute info
    const metaYamlPluginInfos: MetaYamlPluginInfo[] = await Promise.all(
      cheEditors.map(async (cheEditor: CheEditorMetaInfo) => {
        const type = 'Che Editor';
        const cheEditorOutput = JSON.stringify(cheEditor);

        const metadata = cheEditor.metadata;
        const id = metadata.name;
        const splitIds = id.split('/');
        if (splitIds.length !== 3) {
          throw new Error(`The id for ${cheEditorOutput} is not composed of 3 parts separated by / like <1>/<2>/<3>`);
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

        const displayName = metadata.displayName;
        const title = metadata.attributes.title;
        const description = metadata.description;
        const category = 'Editor';
        const iconFile = cheEditor.iconFile;
        const repository = metadata.attributes.repository;
        const firstPublicationDate = metadata.attributes.firstPublicationDate;

        const latestUpdateDate = new Date().toISOString().slice(0, 10);
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const spec: any = {};
        if (cheEditor.components) {
          spec.endpoints = [];
          spec.containers = [];
          spec.initContainers = [];
          cheEditor.components.forEach(c => {
            if (c.container && c.container.endpoints) {
              c.container.endpoints.forEach(e => spec.endpoints.push(this.endpointsHelper.resolve(e)));
            }
          });
          const containers = this.containerHelper.resolve(cheEditor);
          spec.containers.push(...containers.containers);
          spec.initContainers.push(...containers.initContainers);
        }

        return {
          id: metaId,
          disableLatest,
          publisher,
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
