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

/**
 * Update all reference to images to use dev prefix to use dev images instead of production images that may not be available yet.
 * For instance, CodeReady Workspaces is using prefix `registry.redhat.io/codeready-workspaces` but for developers it would be `quay.io/crw`
 */
@injectable()
export class DevImagesHelper {

  async replaceImagePrefix(metaYamlPluginInfos: MetaYamlPluginInfo[], prodImagePrefix: string, devImagePrefix: string): Promise<MetaYamlPluginInfo[]> {
    return Promise.all(
      metaYamlPluginInfos.map(async plugin => {
        const spec = plugin.spec;
        if (spec) {
          if (spec.containers) {
            await Promise.all(
              spec.containers.map(
                async container => (container.image = container.image.replace(prodImagePrefix, devImagePrefix))
              )
            );
          }
          if (spec.initContainers) {
            await Promise.all(
              spec.initContainers.map(
                async container => (container.image = container.image.replace(prodImagePrefix, devImagePrefix))
              )
            );
          }
        }
        return plugin;
      })
    );
  }
}
