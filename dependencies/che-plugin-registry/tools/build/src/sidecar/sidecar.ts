/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
import {
  CheTheiaPluginSidecarDirectoryYaml,
  CheTheiaPluginSidecarImageYaml,
} from '../che-theia-plugin/che-theia-plugins-yaml';
import { inject, injectable } from 'inversify';

import { CheTheiaPluginMetaInfo } from '../build';
import { SidecarDockerImage } from './sidecar-docker-image';

@injectable()
export class Sidecar {
  @inject(SidecarDockerImage)
  private sidecarDockerImage: SidecarDockerImage;

  protected isSideCarDirectory(
    sidecar: CheTheiaPluginSidecarDirectoryYaml | CheTheiaPluginSidecarImageYaml
  ): sidecar is CheTheiaPluginSidecarDirectoryYaml {
    return (sidecar as CheTheiaPluginSidecarDirectoryYaml).directory !== undefined;
  }

  async getDockerImageFor(cheTheiaPluginMetaInfo: CheTheiaPluginMetaInfo): Promise<string | undefined> {
    if (!cheTheiaPluginMetaInfo.sidecar) {
      return undefined;
    } else if (this.isSideCarDirectory(cheTheiaPluginMetaInfo.sidecar)) {
      return this.sidecarDockerImage.getDockerImageFor(
        (cheTheiaPluginMetaInfo.sidecar as CheTheiaPluginSidecarDirectoryYaml).directory
      );
    } else {
      return (cheTheiaPluginMetaInfo.sidecar as CheTheiaPluginSidecarImageYaml).image;
    }
  }
}
