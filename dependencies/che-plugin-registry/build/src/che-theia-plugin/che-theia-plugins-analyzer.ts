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
import * as jsyaml from 'js-yaml';

import { CheTheiaPluginsYaml } from './che-theia-plugins-yaml';
import { injectable } from 'inversify';

/**
 * Analyze che-theia-plugins.yaml URL
 */
@injectable()
export class CheTheiaPluginsAnalyzer {
  async analyze(cheTheiaPluginsFile: string): Promise<CheTheiaPluginsYaml> {
    const content = await fs.readFile(cheTheiaPluginsFile, 'utf-8');

    const cheTheiaPluginsYaml: CheTheiaPluginsYaml = jsyaml.safeLoad(content, {
      schema: jsyaml.JSON_SCHEMA,
    }) as CheTheiaPluginsYaml;

    return cheTheiaPluginsYaml;
  }
}
