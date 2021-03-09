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

import { CheTheiaPluginsAnalyzer } from '../../src/che-theia-plugin/che-theia-plugins-analyzer';
import { Container } from 'inversify';

describe('Test CheTheiaPluginsAnalyzer', () => {
  let container: Container;

  let cheTheiaPluginsAnalyzer: CheTheiaPluginsAnalyzer;

  beforeEach(() => {
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind(CheTheiaPluginsAnalyzer).toSelf().inSingletonScope();
    cheTheiaPluginsAnalyzer = container.get(CheTheiaPluginsAnalyzer);
  });

  test('basics', async () => {
    const testContentPath = path.resolve(__dirname, '..', '..', '..', '..', 'che-theia-plugins.yaml');
    const result = await cheTheiaPluginsAnalyzer.analyze(testContentPath);
    expect(result).toBeDefined();
    expect(result.plugins).toBeDefined();
    expect(result.plugins.length).toBeGreaterThan(10);

    // search for plugins with an id provided in yaml
    const java11Plugins = result.plugins.filter(plugin => plugin.id === 'redhat/java11');
    expect(java11Plugins).toBeDefined();
    expect(java11Plugins.length).toBe(1);
    const java11Plugin = java11Plugins[0];
    expect(java11Plugin.repository.url).toBe('https://github.com/redhat-developer/vscode-java');

    // search without id as it is not provided
    const goPlugins = result.plugins.filter(plugin => plugin.repository.url === 'https://github.com/golang/vscode-go');
    expect(goPlugins).toBeDefined();
    expect(goPlugins.length).toBe(1);
    const goPlugin = goPlugins[0];
    expect(goPlugin.id).toBeUndefined();
    expect(goPlugin.repository.revision).toBeDefined();
  });
});
