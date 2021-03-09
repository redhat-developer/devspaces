/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/

import { VsixCategory, VsixInfo } from '../extensions/vsix-info';

export interface MetaYamlPluginInfo {
  id: string;
  publisher: string;
  name: string;
  version: string;
  type: 'VS Code extension' | 'Che Editor' | 'Che Plugin';
  displayName: string;
  title: string;
  description: string;
  iconFile?: string;
  category: VsixCategory | 'Editor';
  repository: string;
  firstPublicationDate: string;
  latestUpdateDate: string;
  aliases?: string[];
  spec: {
    containers?: [{ image: string; command?: string[]; args?: string[] }];
    initContainers?: [{ image: string }];
    extensions: string[];
  };
  // do not write latest alias
  disableLatest?: boolean;

  vsixInfos: Map<string, VsixInfo>;
}
