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

import { CheEditorsYaml } from './che-editors-yaml';
import { injectable } from 'inversify';

/**
 * Analyze che-editors.yaml URL
 */
@injectable()
export class CheEditorsAnalyzer {
  async analyze(cheEditorFile: string): Promise<CheEditorsYaml> {
    const content = await fs.readFile(cheEditorFile, 'utf-8');

    const cheEditorsYaml: CheEditorsYaml = jsyaml.safeLoad(content, {
      schema: jsyaml.JSON_SCHEMA,
    }) as CheEditorsYaml;

    return cheEditorsYaml;
  }
}
