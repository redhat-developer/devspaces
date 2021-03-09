/**********************************************************************
 * Copyright (c) 2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
/* eslint-disable @typescript-eslint/no-explicit-any */
import 'reflect-metadata';

import * as fs from 'fs-extra';

import { Container } from 'inversify';
import { IndexWriter } from '../../src/meta-yaml/index-writer';
import { MetaYamlPluginInfo } from '../../src/meta-yaml/meta-yaml-plugin-info';

describe('Test IndexWriter', () => {
  let container: Container;

  let metaYamlPlugins: MetaYamlPluginInfo[];
  let indexWriter: IndexWriter;

  beforeEach(() => {
    metaYamlPlugins = [
      // first plug-in has both containers and init containers
      {
        description: 'my-description',
        displayName: 'display-name',
        id: 'my-publisher/my-name/latest',
        name: 'my-name',
        publisher: 'my-publisher',
        type: 'VS Code extension',
        version: 'my-version',
      } as any,
      {
        description: 'my-che-plugin',
        displayName: 'display-name-che-plugin',
        id: 'my-publisher/my-che-plugin-name/latest',
        name: 'my-che-plugin-name',
        publisher: 'my-publisher',
        type: 'Che Plugin',
        version: 'my-version',
      } as any,
      {
        description: 'my-che-plugin',
        displayName: 'display-name-che-editor',
        id: 'my-publisher/my-che-editor-name/latest',
        name: 'my-che-editor-name',
        publisher: 'my-publisher',
        type: 'Che Editor',
        version: 'my-version',
      } as any,
    ];
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind('string').toConstantValue('/fake-output').whenTargetNamed('OUTPUT_ROOT_DIRECTORY');

    container.bind(IndexWriter).toSelf().inSingletonScope();
    indexWriter = container.get(IndexWriter);
  });

  test('basics', async () => {
    const fsEnsureDirSpy = jest.spyOn(fs, 'ensureDir');
    const fsWriteFileSpy = jest.spyOn(fs, 'writeFile');

    fsEnsureDirSpy.mockReturnValue();
    fsWriteFileSpy.mockReturnValue();

    await indexWriter.write(metaYamlPlugins);

    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(1, '/fake-output/v3/plugins');

    expect(fsWriteFileSpy.mock.calls[0][0]).toBe('/fake-output/v3/plugins/index.json');
    const jsonOutput = JSON.parse(fsWriteFileSpy.mock.calls[0][1]);
    // result has been sorted
    expect(jsonOutput[0].id).toBe('my-publisher/my-che-editor-name/latest');
    expect(jsonOutput[0].description).toBe('my-che-plugin');
    expect(jsonOutput[0].links.self).toBe('/v3/plugins/my-publisher/my-che-editor-name/latest');
    expect(jsonOutput[0].links.devfile).toBe('/v3/plugins/my-publisher/my-che-editor-name/latest/devfile.yaml');
    expect(jsonOutput[0].name).toBe('my-che-editor-name');
    expect(jsonOutput[0].publisher).toBe('my-publisher');
    expect(jsonOutput[0].type).toBe('Che Editor');
    expect(jsonOutput[0].version).toBe('my-version');

    expect(jsonOutput[1].id).toBe('my-publisher/my-che-plugin-name/latest');
    expect(jsonOutput[1].description).toBe('my-che-plugin');
    expect(jsonOutput[1].links.self).toBe('/v3/plugins/my-publisher/my-che-plugin-name/latest');
    expect(jsonOutput[1].links.devfile).toBe('/v3/plugins/my-publisher/my-che-plugin-name/latest/devfile.yaml');
    expect(jsonOutput[1].name).toBe('my-che-plugin-name');
    expect(jsonOutput[1].publisher).toBe('my-publisher');
    expect(jsonOutput[1].type).toBe('Che Plugin');
    expect(jsonOutput[1].version).toBe('my-version');

    expect(jsonOutput[2].id).toBe('my-publisher/my-name/latest');
    expect(jsonOutput[2].description).toBe('my-description');
    expect(jsonOutput[2].links.self).toBe('/v3/plugins/my-publisher/my-name/latest');
    // no devfile generation for VS Code extensions
    expect(jsonOutput[2].links.devfile).toBeUndefined();
    expect(jsonOutput[2].name).toBe('my-name');
    expect(jsonOutput[2].publisher).toBe('my-publisher');
    expect(jsonOutput[2].type).toBe('VS Code extension');
    expect(jsonOutput[2].version).toBe('my-version');
  });
});
