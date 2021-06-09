/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
/* eslint-disable @typescript-eslint/no-explicit-any */
import 'reflect-metadata';

import * as path from 'path';

import { ChePluginsAnalyzer } from '../../src/che-plugin/che-plugins-analyzer';
import { Container } from 'inversify';

describe('Test ChePluginsAnalyzer', () => {
  let container: Container;

  let chePluginsAnalyzer: ChePluginsAnalyzer;

  beforeEach(() => {
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind(ChePluginsAnalyzer).toSelf().inSingletonScope();
    chePluginsAnalyzer = container.get(ChePluginsAnalyzer);
  });

  test('basics', async () => {
    const testContentPath = path.resolve(__dirname, '..', '..', '..', '..', 'che-plugins.yaml');
    const result = await chePluginsAnalyzer.analyze(testContentPath);
    expect(result).toBeDefined();
    expect(result.plugins).toBeDefined();
    expect(result.plugins.length).toBe(1);
  });
});
