/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
import { VsixPackageJsonContributesLanguage } from '../extensions/vsix-info';

export interface FeaturedItemContributesJson {
  languages: VsixPackageJsonContributesLanguage[];
}

export interface FeaturedItemJson {
  id: string;
  workspaceContains: string[];
  onLanguages: string[];
  contributes: FeaturedItemContributesJson;
}

export interface FeaturedJson {
  version: string;
  featured: FeaturedItemJson[];
}
