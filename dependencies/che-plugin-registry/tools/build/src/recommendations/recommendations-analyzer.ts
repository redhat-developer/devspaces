/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
import { VsixCategory, VsixPackageJsonContributesLanguage } from '../extensions/vsix-info';

import { CheTheiaPluginMetaInfo } from '../build';
import { injectable } from 'inversify';

export interface RecommendationChePluginMetaInfo extends CheTheiaPluginMetaInfo {
  activationEvents: string[];
  contributeLanguages: VsixPackageJsonContributesLanguage[];
  categories: VsixCategory[];
}

export interface RecommendationInfoCategory {
  category: VsixCategory;
  ids: Set<string>;
}

export interface RecommendationResult {
  perExtensions: Map<string, RecommendationInfoCategory[]>;
  perLanguages: Map<string, RecommendationInfoCategory[]>;
}

@injectable()
export class RecommendationsAnalyzer {
  async generate(cheTheiaPlugins: CheTheiaPluginMetaInfo[]): Promise<RecommendationResult> {
    // for each plugin, grab the onLanguage
    const recommandedPlugins: RecommendationChePluginMetaInfo[] = cheTheiaPlugins.map(chePlugin => {
      const activationEvents: string[] = [];
      const contributeLanguages: VsixPackageJsonContributesLanguage[] = [];
      const categories: VsixCategory[] = [];
      const recommandedPlugin: RecommendationChePluginMetaInfo = {
        ...chePlugin,
        activationEvents,
        contributeLanguages,
        categories,
      };
      Array.from(chePlugin.vsixInfos.values()).forEach(vsixInfo => {
        const pluginActivationEvents = vsixInfo.packageJson?.activationEvents || [];
        recommandedPlugin.activationEvents.push(...pluginActivationEvents);

        const contributes = vsixInfo.packageJson?.contributes || { languages: [] };
        const contributesLanguages = contributes.languages || [];
        recommandedPlugin.contributeLanguages.push(...contributesLanguages);

        const pluginCategories = vsixInfo.packageJson?.categories || [];
        recommandedPlugin.categories.push(...pluginCategories);
      });
      return recommandedPlugin;
    });

    const perExtensions: Map<string, RecommendationInfoCategory[]> = new Map();
    const perLanguages: Map<string, RecommendationInfoCategory[]> = new Map();

    recommandedPlugins.forEach(chePlugin => {
      const onLanguageEvents = chePlugin.activationEvents.filter(event => event.startsWith('onLanguage:'));
      onLanguageEvents.forEach(language => {
        const languageIdentifier = language.substring('onLanguage:'.length);
        const existingList = perLanguages.get(languageIdentifier) || [];
        perLanguages.set(languageIdentifier, existingList);

        chePlugin.categories.forEach(chePluginCategory => {
          let recommendationInfoCategory: RecommendationInfoCategory | undefined;
          existingList.forEach(analyzingRecommendationInfoCategory => {
            if (analyzingRecommendationInfoCategory.category === chePluginCategory) {
              recommendationInfoCategory = analyzingRecommendationInfoCategory;
            }
          });

          if (!recommendationInfoCategory) {
            recommendationInfoCategory = { category: chePluginCategory, ids: new Set() };
            existingList.push(recommendationInfoCategory);
          }
          // it's a set so only add if not there
          recommendationInfoCategory.ids.add(chePlugin.id);
        });
      });

      // get extension
      chePlugin.contributeLanguages.forEach(language => {
        if (language.extensions) {
          language.extensions.forEach(fileExtension => {
            const existingList = perExtensions.get(fileExtension) || [];
            perExtensions.set(fileExtension, existingList);

            chePlugin.categories.forEach(chePluginCategory => {
              let recommendationInfoCategory: RecommendationInfoCategory | undefined;
              existingList.forEach(analyzingRecommendationInfoCategory => {
                if (analyzingRecommendationInfoCategory.category === chePluginCategory) {
                  recommendationInfoCategory = analyzingRecommendationInfoCategory;
                }
              });
              if (!recommendationInfoCategory) {
                recommendationInfoCategory = { category: chePluginCategory, ids: new Set() };
                existingList.push(recommendationInfoCategory);
              }
              recommendationInfoCategory.ids.add(chePlugin.id);
            });
          });
        }
      });
    });

    return { perExtensions, perLanguages };
  }
}
