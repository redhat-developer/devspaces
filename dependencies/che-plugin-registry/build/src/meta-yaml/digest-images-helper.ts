/**********************************************************************
 * Copyright (c) 2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/

import { inject, injectable } from 'inversify';

import { MetaYamlPluginInfo } from './meta-yaml-plugin-info';
import { RegistryHelper } from '../registry/registry-helper';

/**
 * Update all reference to images to use digest instead of tags.
 */
@injectable()
export class DigestImagesHelper {
  @inject(RegistryHelper)
  private registryHelper: RegistryHelper;

  async updateImages(metaYamlPluginInfos: MetaYamlPluginInfo[]): Promise<MetaYamlPluginInfo[]> {
    return Promise.all(
      metaYamlPluginInfos.map(async plugin => {
        const spec = plugin.spec;
        if (spec) {
          if (spec.containers) {
            await Promise.all(
              spec.containers.map(
                async container => (container.image = await this.registryHelper.getImageDigest(container.image))
              )
            );
          }
          if (spec.initContainers) {
            await Promise.all(
              spec.initContainers.map(
                async container => (container.image = await this.registryHelper.getImageDigest(container.image))
              )
            );
          }
        }
        return plugin;
      })
    );
  }
}
