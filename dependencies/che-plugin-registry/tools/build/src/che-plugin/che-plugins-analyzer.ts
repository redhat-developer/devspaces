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

import { ChePluginsYaml } from './che-plugins-yaml';
import { injectable } from 'inversify';

/**
 * Analyze che-plugins.yaml file
 */
@injectable()
export class ChePluginsAnalyzer {
  async analyze(cheEditorFile: string): Promise<ChePluginsYaml> {
    const content = await fs.readFile(cheEditorFile, 'utf-8');

    const chePluginsYaml: ChePluginsYaml = jsyaml.safeLoad(content, {
      schema: jsyaml.JSON_SCHEMA,
    }) as ChePluginsYaml;

    return chePluginsYaml;
  }
}
