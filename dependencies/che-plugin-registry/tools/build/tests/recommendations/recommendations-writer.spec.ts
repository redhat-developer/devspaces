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

import * as fs from 'fs-extra';

import { RecommendationInfoCategory, RecommendationResult } from '../../src/recommendations/recommendations-analyzer';

import { Container } from 'inversify';
import { RecommendationsWriter } from '../../src/recommendations/recommendations-writer';

describe('Test Featured', () => {
  let container: Container;

  let recommendationsWriter: RecommendationsWriter;

  beforeEach(() => {
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind(RecommendationsWriter).toSelf().inSingletonScope();
    container.bind('string').toConstantValue('/fake-output').whenTargetNamed('OUTPUT_ROOT_DIRECTORY');

    recommendationsWriter = container.get(RecommendationsWriter);
  });

  test('basics', async () => {
    const ensureDirSpy = jest.spyOn(fs, 'ensureDir');
    ensureDirSpy.mockReturnValue();

    const perExtensions = new Map<string, RecommendationInfoCategory[]>();
    const perLanguages = new Map<string, RecommendationInfoCategory[]>();

    const featuredJson: RecommendationResult = { perExtensions, perLanguages };

    const javaIds = new Set<string>();
    javaIds.add('my-plugin-1');
    javaIds.add('my-plugin-2');
    const javaRecommendationCategory: RecommendationInfoCategory = {
      category: 'Programming Languages',
      ids: javaIds,
    };
    perLanguages.set('java', [javaRecommendationCategory]);

    const writeFileSpy = jest.spyOn(fs, 'writeFile');
    writeFileSpy.mockReturnValue();

    await recommendationsWriter.writeRecommendations(featuredJson);

    // only one file being written now
    expect(writeFileSpy).toBeCalledTimes(1);
    // check we ensure parent folder exists
    expect(ensureDirSpy).toBeCalled();

    const callWrite = writeFileSpy.mock.calls[0];
    // write path is ok
    expect(callWrite[0]).toBe('/fake-output/v3/che-theia/recommendations/language/java.json');

    // should be indented with 2 spaces
    expect(callWrite[1]).toBe(
      '[\n  {\n    "category": "Programming Languages",\n    "ids": [\n      "my-plugin-1",\n      "my-plugin-2"\n    ]\n  }\n]\n'
    );
  });
});
