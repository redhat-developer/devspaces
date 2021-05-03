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

import { CheTheiaPluginMetaInfo } from '../build';
import { FeaturedJson } from './featured-json';
import { VsixPackageJsonContributesLanguage } from '../extensions/vsix-info';

export interface FeaturedChePluginMetaInfo extends CheTheiaPluginMetaInfo {
  workspaceContains: string[];
  onLanguages: string[];
  contributeLanguages: VsixPackageJsonContributesLanguage[];
}

@injectable()
export class FeaturedWriter {
  @inject('string')
  @named('OUTPUT_ROOT_DIRECTORY')
  private outputRootDirectory: string;

  async writeReport(featuredJson: FeaturedJson): Promise<void> {
    // now, write the files
    const featuredFolder = path.resolve(this.outputRootDirectory, 'v3', 'che-theia');
    await fs.ensureDir(featuredFolder);
    const featuredJsonPath = path.resolve(featuredFolder, 'featured.json');

    await fs.writeFile(featuredJsonPath, `${JSON.stringify(featuredJson, undefined, 2)}\n`);
  }
}
