/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
import { CheTheiaPluginMetaInfo } from '../build';
import { FeaturedJson } from './featured-json';
import { VsixPackageJsonContributesLanguage } from '../extensions/vsix-info';
import { injectable } from 'inversify';

export interface FeaturedChePluginMetaInfo extends CheTheiaPluginMetaInfo {
  workspaceContains: string[];
  onLanguages: string[];
  contributeLanguages: VsixPackageJsonContributesLanguage[];
}

@injectable()
export class FeaturedAnalyzer {
  async generate(cheTheiaPlugins: CheTheiaPluginMetaInfo[]): Promise<FeaturedJson> {
    const featuredCheTheiaPlugins = cheTheiaPlugins.filter(plugin => plugin.featured === true);
    // for each plugin, grab the workspaceContains, onLanguage and contributes
    const featuredPlugins: FeaturedChePluginMetaInfo[] = featuredCheTheiaPlugins.map(cheTheiaPlugin => {
      const workspaceContains: string[] = [];
      const onLanguages: string[] = [];
      const contributeLanguages: VsixPackageJsonContributesLanguage[] = [];
      const featuredPlugin: FeaturedChePluginMetaInfo = {
        ...cheTheiaPlugin,
        onLanguages,
        workspaceContains,
        contributeLanguages,
      };
      Array.from(cheTheiaPlugin.vsixInfos.values()).forEach(vsixInfo => {
        const activationEvents = vsixInfo.packageJson?.activationEvents || [];
        const workspaceContainsList = activationEvents
          .filter(activationEvent => activationEvent.startsWith('workspaceContains:'))
          .map(activationEvent => activationEvent.substring('workspaceContains:'.length));
        const onLanguageList = activationEvents
          .filter(activationEvent => activationEvent.startsWith('onLanguage:'))
          .map(activationEvent => activationEvent.substring('onLanguage:'.length));
        featuredPlugin.workspaceContains.push(...workspaceContainsList);
        featuredPlugin.onLanguages.push(...onLanguageList);

        const contributes = vsixInfo.packageJson?.contributes || { languages: [] };
        const contributesLanguages = contributes.languages || [];
        featuredPlugin.contributeLanguages.push(...contributesLanguages);

        // keep only id/aliases/filenames/filenamePatterns
        const keepKeys = ['id', 'aliases', 'filenames', 'filenamePatterns'];
        contributeLanguages.forEach(language => {
          Object.keys(language).forEach(key => {
            if (!keepKeys.includes(key)) {
              // eslint-disable-next-line @typescript-eslint/no-explicit-any
              delete (language as any)[key];
            }
          });
        });
      });
      return featuredPlugin;
    });

    const featuredItems = featuredPlugins.map(featuredPlugin => ({
      id: featuredPlugin.id,
      onLanguages: featuredPlugin.onLanguages,
      workspaceContains: featuredPlugin.workspaceContains,
      contributes: { languages: featuredPlugin.contributeLanguages },
    }));

    const featuredJson = {
      version: '1.0.0',
      featured: featuredItems,
    };
    return featuredJson;
  }
}
