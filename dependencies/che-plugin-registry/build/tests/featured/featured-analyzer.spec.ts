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

import { CheTheiaPluginGenerator } from '../packages/che-theia-plugins-generator';
import { CheTheiaPluginMetaInfo } from '../../src/build';
import { Container } from 'inversify';
import { FeaturedAnalyzer } from '../../src/featured/featured-analyzer';

describe('Test Featured', () => {
  let container: Container;

  let featuredAnalyzer: FeaturedAnalyzer;
  let cheTheiaPlugins: CheTheiaPluginMetaInfo[];

  beforeEach(async () => {
    const generator = new CheTheiaPluginGenerator();
    cheTheiaPlugins = await generator.generate();
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind(FeaturedAnalyzer).toSelf().inSingletonScope();
    featuredAnalyzer = container.get(FeaturedAnalyzer);
  });

  test('basics', async () => {
    const result = await featuredAnalyzer.generate(cheTheiaPlugins);
    expect(result).toBeDefined();

    expect(result.version).toBe('1.0.0');
    const items = result.featured;
    expect(items).toBeDefined();
    expect(items.length).toBe(4);

    // only vscode-java is interesting, other one are fake one
    const vscodeJavaItem = items[0];

    expect(vscodeJavaItem.id).toBe('vscode-java');
    expect(vscodeJavaItem.onLanguages).toStrictEqual(['java']);
    expect(vscodeJavaItem.workspaceContains).toStrictEqual(['pom.xml', 'build.gradle', '.classpath']);
    expect(vscodeJavaItem.contributes).toStrictEqual({ languages: [{ id: 'java' }] });
  });
});
