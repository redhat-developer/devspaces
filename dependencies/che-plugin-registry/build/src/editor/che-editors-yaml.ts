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
  args?: string[];
  command?: string[];
  dedicatedPod?: boolean;
  endpoints?: CommonEndpointYaml[];
  env?: CommonEnvYaml[];
  image: string;
  memoryLimit?: string;
  mountSources?: boolean;
  sourceMapping?: string;
  volumeMounts?: CommonVolumeMountYaml[];
}

interface CheEditorPlatformYaml {
  inlined?: string;
  uri?: string;
  endpoints?: CommonEndpointYaml[];
}

interface CheEditorKubernetesYaml {
  name: string;
  namespace?: string;
}

interface CheEditorPluginYaml {
  id?: string;
  kubernetes?: CheEditorKubernetesYaml;
  uri?: string;
  commands?: CheEditorCommandYaml[];
  components?: CheEditorComponentYaml[];
  registryUrl?: string;
}

export interface CheEditorVolume {
  ephemeral?: boolean;
  size?: string;
}

export interface CheEditorComponentYaml {
  container?: CheEditorContainerYaml;
  kubernetes?: CheEditorPlatformYaml;
  openshift?: CheEditorPlatformYaml;
  plugin?: CheEditorPluginYaml;
  volume?: CheEditorVolume;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  attributes?: { [key: string]: any };
  name?: string;
}

interface CheEditorCompositeYaml {
  commands?: string[];
  group?: CheEditorGroupYaml;
  label?: string;
  parallel?: boolean;
}

interface CheEditorExecYaml {
  commandLine: string;
  component: string;
  env?: CommonEnvYaml[];
  group?: CheEditorGroupYaml;
  hotReloadCapable?: boolean;
  label?: string;
  workingDir?: string;
}

interface CheEditorVscodeObjectYaml {
  inlined?: string;
  uri?: string;
  group: CheEditorGroupYaml;
}

interface CheEditorCommandYaml {
  apply?: CheEditorApplyYaml;
  composite?: CheEditorCompositeYaml;
  exec?: CheEditorExecYaml;
  vscodeLaunch?: CheEditorVscodeObjectYaml;
  vscodeTask?: CheEditorVscodeObjectYaml;
  attributes?: { [key: string]: string };
  id?: string;
}

interface CheEditorGroupYaml {
  isDefault?: boolean;
  kind: 'build' | 'run' | 'debug';
}

interface CheEditorApplyYaml {
  component: string;
  group?: CheEditorGroupYaml;
  label?: string;
}

interface CheEditorEventYaml {
  postStart?: string[];
  postStop?: string[];
  preStart?: string[];
  preStop?: string[];
}

interface CheEditorMetadataYaml {
  attributes: { [key: string]: string };
  description?: string;
  displayName?: string;
  globalMemoryLimit?: string;
  icon?: string;
  name: string;
  tags?: string[];
  version?: string;
}

interface CheEditorGitCheckoutFromYaml {
  remote?: string;
  revision?: string;
}

interface CheEditorGitYaml {
  checkoutFrom?: CheEditorGitCheckoutFromYaml;
  remotes?: { [key: string]: string };
}

interface CheEditorProjectYaml {
  git?: CheEditorGitYaml;
  gitHub?: CheEditorGitYaml;
  zip?: { location: string };
  attributes?: { [key: string]: string };
  clonePath?: string;
  description?: string;
  name: string;
  subDir?: string;
  sparseCheckoutDirs?: string[];
}

interface CheEditorParentYaml extends CheEditorPluginYaml {
  projects?: CheEditorProjectYaml[];
  starterProjects?: CheEditorProjectYaml[];
}

export interface CheEditorYaml {
  commands?: CheEditorCommandYaml[];
  components?: CheEditorComponentYaml[];
  events?: CheEditorEventYaml;
  metadata: CheEditorMetadataYaml;
  parent?: CheEditorParentYaml;
  projects?: CheEditorProjectYaml[];
  schemaVersion: string;
  starterProjects?: CheEditorProjectYaml[];
}

export interface CheEditorsYaml {
  editors: CheEditorYaml[];
}
