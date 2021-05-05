/**********************************************************************
 * Copyright (c) 2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/

import { VsixCategory, VsixInfo } from '../extensions/vsix-info';

import { CheTheiaPluginSidecarImageYaml } from './che-theia-plugins-yaml';

export interface CheTheiaPluginYamlInfo {
  aliases?: string[];
  vsixInfos: Map<string, VsixInfo>;
  data: {
    schemaVersion: string;
    metadata: {
      id: string;
      publisher: string;
      name: string;
      version: string;
      displayName: string;
      description: string;
      iconFile?: string;
      repository: string;
      categories: VsixCategory[];
    };
    sidecar?: CheTheiaPluginSidecarImageYaml;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    preferences?: { [key: string]: any };
    extensions: string[];
    dependencies?: string[];
  };
}
