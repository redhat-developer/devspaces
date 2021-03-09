/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
import { CheTheiaPluginSidecarDirectoryYaml, CheTheiaPluginSidecarImageYaml } from './che-theia-plugins-yaml';

import { VsixInfo } from '../extensions/vsix-info';

export interface CheTheiaPluginAnalyzerMetaInfo {
  id?: string;
  featured: boolean;
  extensions: string[];
  aliases: string[];
  sidecar?: CheTheiaPluginSidecarDirectoryYaml | CheTheiaPluginSidecarImageYaml;
  repository: {
    url: string;
    revision: string;
  };
  vsixInfos: Map<string, VsixInfo>;
}
