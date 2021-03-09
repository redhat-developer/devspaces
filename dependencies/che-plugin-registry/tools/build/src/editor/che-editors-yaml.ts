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

export interface CheEditorContainerYaml {
  name: string;
  image: string;
  env?: CommonEnvYaml[];
  mountSources?: boolean;
  memoryRequest?: string;
  memoryLimit?: string;
  cpuRequest?: string;
  cpuLimit?: string;
  volumeMounts?: CommonVolumeMountYaml[];
}

export interface CheEditorYaml {
  id: string;
  title: string;
  displayName: string;
  description: string;
  icon: string;
  repository: string;
  firstPublicationDate: string;
  endpoints?: CommonEndpointYaml[];
  containers?: CheEditorContainerYaml[];
  initContainers?: CheEditorContainerYaml[];
}

export interface CheEditorsYaml {
  editors: CheEditorYaml[];
}
