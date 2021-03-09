/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
import * as fs from 'fs-extra';
import * as path from 'path';

import { inject, injectable, named } from 'inversify';

import { RecommendationResult } from './recommendations-analyzer';

@injectable()
export class RecommendationsWriter {
  @inject('string')
  @named('OUTPUT_ROOT_DIRECTORY')
  private outputRootDirectory: string;

  async writeRecommendations(recommendationResult: RecommendationResult): Promise<void> {
    // now, write the files
    const recommendationsFolder = path.resolve(this.outputRootDirectory, 'v3', 'che-theia', 'recommendations');
    const languageFolder = path.resolve(recommendationsFolder, 'language');
    await fs.ensureDir(languageFolder);
    await Promise.all(
      Array.from(recommendationResult.perLanguages.entries())
        .sort()
        .map(entry => {
          const languageID = entry[0];
          const langCategories = entry[1];
          const languageFile = path.resolve(languageFolder, `${languageID}.json`);
          const perLanguageEntries = langCategories.map(recommendationCategory => ({
            category: recommendationCategory.category,
            ids: Array.from(recommendationCategory.ids),
          }));
          return fs.writeFile(languageFile, `${JSON.stringify(perLanguageEntries, undefined, 2)}\n`);
        })
    );
  }
}
