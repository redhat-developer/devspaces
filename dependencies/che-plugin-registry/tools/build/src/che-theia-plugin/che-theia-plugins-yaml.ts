/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/

import { CommonEndpointYaml } from '../common/common-endpoint-yaml';
import { CommonEnvYaml } from '../common/common-env-yaml';
import { CommonVolumeMountYaml } from '../common/common-volume-mount-yaml';

export interface AbsCheTheiaPluginSidecarYaml {
  name?: string;
  mountSources?: boolean;
  memoryRequest?: string;
  memoryLimit?: string;
  cpuRequest?: string;
  cpuLimit?: string;
  command?: string[];
  args?: string[];
  volumeMounts?: CommonVolumeMountYaml[];
  endpoints?: CommonEndpointYaml[];
  env?: CommonEnvYaml[];
}

export interface CheTheiaPluginSidecarDirectoryYaml extends AbsCheTheiaPluginSidecarYaml {
  directory: string;
}

export interface CheTheiaPluginSidecarImageYaml extends AbsCheTheiaPluginSidecarYaml {
  image: string;
}

export interface CheTheiaPluginYaml {
  id?: string;
  featured?: boolean;
  aliases?: string[];
  sidecar?: CheTheiaPluginSidecarDirectoryYaml | CheTheiaPluginSidecarImageYaml;
  repository: {
    url: string;
    revision: string;
  };
  extensions: string[];
}

export interface CheTheiaPluginsYaml {
  plugins: CheTheiaPluginYaml[];
}
