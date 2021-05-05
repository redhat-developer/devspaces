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
    expect(result.plugins.length).toBeGreaterThan(4);

    // search for plugins with an id provided in yaml
    const buildahPlugins = result.plugins.filter(plugin => plugin.id === 'containers/buildah/1.14.0');
    expect(buildahPlugins).toBeDefined();
    expect(buildahPlugins.length).toBe(1);
    const buildahPlugin = buildahPlugins[0];
    expect(buildahPlugin.repository).toBe('https://github.com/containers/buildah');
  });
});
