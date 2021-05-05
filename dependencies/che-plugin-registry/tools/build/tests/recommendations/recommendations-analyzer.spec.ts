/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
import 'reflect-metadata';

import { CheTheiaPluginGenerator } from '../packages/che-theia-plugins-generator';
import { CheTheiaPluginMetaInfo } from '../../src/build';
import { Container } from 'inversify';
import { RecommendationsAnalyzer } from '../../src/recommendations/recommendations-analyzer';

describe('Test RecommendationsAnalyzer', () => {
  let container: Container;

  let recommendationsAnalyzer: RecommendationsAnalyzer;
  let cheTheiaPlugins: CheTheiaPluginMetaInfo[];

  beforeEach(async () => {
    const generator = new CheTheiaPluginGenerator();
    cheTheiaPlugins = await generator.generate();
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind(RecommendationsAnalyzer).toSelf().inSingletonScope();
    recommendationsAnalyzer = container.get(RecommendationsAnalyzer);
  });

  test('basics', async () => {
    const result = await recommendationsAnalyzer.generate(cheTheiaPlugins);
    expect(result).toBeDefined();

    const { perLanguages, perExtensions } = result;

    expect(perLanguages).toBeDefined();
    expect(perExtensions).toBeDefined();

    const dotClassExtensionsRecommendations = perExtensions.get('.class') || [];
    expect(dotClassExtensionsRecommendations.length).toBeGreaterThan(3);
    const linters = dotClassExtensionsRecommendations.filter(item => item.category === 'Linters');
    expect(linters.length).toBe(1);
    expect(Array.from(linters[0].ids)).toStrictEqual(['vscode-java', 'vscode-incomplete']);

    const goLanguageRecommendations = perLanguages.get('go') || [];
    expect(goLanguageRecommendations.length).toBeGreaterThan(4);
    const debuggers = goLanguageRecommendations.filter(item => item.category === 'Debuggers');
    expect(debuggers.length).toBe(1);
    expect(Array.from(debuggers[0].ids)).toStrictEqual(['vscode-go']);
  });
});
