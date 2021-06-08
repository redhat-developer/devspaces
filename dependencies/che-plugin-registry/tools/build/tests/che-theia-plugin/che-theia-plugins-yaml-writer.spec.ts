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

import { CheTheiaPluginYamlInfo } from '../../src/che-theia-plugin/che-theia-plugin-yaml-info';
import { CheTheiaPluginsYamlWriter } from '../../src/che-theia-plugin/che-theia-plugins-yaml-writer';
import { Container } from 'inversify';
import { VsixInfo } from '../../src/extensions/vsix-info';

describe('Test CheTheiaPluginsYamlWriter', () => {
  let container: Container;

  let cheTheiaPluginYaml: CheTheiaPluginYamlInfo;
  let cheTheiaPluginsYamlWriter: CheTheiaPluginsYamlWriter;
  let embedVsix = false;
  const vsixInfos = new Map<string, VsixInfo>();

  function initContainer() {
    container = new Container();
    container.bind('string').toConstantValue('/fake-output').whenTargetNamed('OUTPUT_ROOT_DIRECTORY');
    container.bind('boolean').toConstantValue(embedVsix).whenTargetNamed('EMBED_VSIX');
    container.bind(CheTheiaPluginsYamlWriter).toSelf().inSingletonScope();
  }

  beforeEach(() => {
    vsixInfos.clear();

    cheTheiaPluginYaml = {
      aliases: ['first/alias', 'second/alias'],
      vsixInfos,
      data: {
        schemaVersion: '1.0.0',
        metadata: {
          id: 'custom-publisher/custom-name',
          publisher: 'my-publisher',
          name: 'my-name',
          version: 'latest',
          displayName: 'display-name',
          description: 'my-description',
          iconFile: '/fake-dir/icon.png',
          categories: ['Programming Languages'],
          repository: 'http://fake-repository',
        },
        sidecar: {
          image: 'foo',
        },
        dependencies: ['my-dependency'],
        preferences: {
          'foo.bar': 'foo',
        },
        extensions: ['http://my-first.vsix'],
      },
    };
    jest.restoreAllMocks();
    jest.resetAllMocks();
    initContainer();
    cheTheiaPluginsYamlWriter = container.get(CheTheiaPluginsYamlWriter);
  });

  test('basics', async () => {
    const fsCopyFileSpy = jest.spyOn(fs, 'copyFile');
    const fsEnsureDirSpy = jest.spyOn(fs, 'ensureDir');
    const fsWriteFileSpy = jest.spyOn(fs, 'writeFile');

    fsEnsureDirSpy.mockReturnValue();
    fsCopyFileSpy.mockReturnValue();
    fsWriteFileSpy.mockReturnValue();

    const cheTheiaPlugins: CheTheiaPluginYamlInfo[] = [cheTheiaPluginYaml];
    await cheTheiaPluginsYamlWriter.write(cheTheiaPlugins);

    expect(fsCopyFileSpy).toHaveBeenCalledWith(
      '/fake-dir/icon.png',
      '/fake-output/v3/images/my-publisher-my-name-icon.png'
    );
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(1, '/fake-output/v3/plugins');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(2, '/fake-output/v3/images');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(3, '/fake-output/v3/resources');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(4, '/fake-output/v3/plugins/custom-publisher/custom-name/latest');
    const content = `schemaVersion: 1.0.0
metadata:
  id: custom-publisher/custom-name
  publisher: custom-publisher
  name: custom-name
  version: latest
  displayName: display-name
  description: my-description
  categories:
    - Programming Languages
  repository: 'http://fake-repository'
  icon: /images/my-publisher-my-name-icon.png
sidecar:
  image: foo
dependencies:
  - my-dependency
preferences:
  foo.bar: foo
extensions:
  - 'http://my-first.vsix'
`;
    expect(fsWriteFileSpy).toHaveBeenNthCalledWith(
      1,
      '/fake-output/v3/plugins/custom-publisher/custom-name/latest/che-theia-plugin.yaml',
      content
    );

    // check that alias is also being written (and alias is deprecated)
    const aliasContent = content.replace(/custom-publisher/g, 'first').replace(/custom-name/g, 'alias');
    expect(fsWriteFileSpy).toHaveBeenNthCalledWith(
      2,
      '/fake-output/v3/plugins/first/alias/latest/che-theia-plugin.yaml',
      aliasContent
    );
  });

  test('default icon', async () => {
    const fsCopyFileSpy = jest.spyOn(fs, 'copyFile');
    const fsEnsureDirSpy = jest.spyOn(fs, 'ensureDir');
    const fsWriteFileSpy = jest.spyOn(fs, 'writeFile');

    fsEnsureDirSpy.mockReturnValue();
    fsCopyFileSpy.mockReturnValue();
    fsWriteFileSpy.mockReturnValue();
    delete cheTheiaPluginYaml.data.metadata.iconFile;
    delete cheTheiaPluginYaml.aliases;
    const cheTheiaPlugins: CheTheiaPluginYamlInfo[] = [cheTheiaPluginYaml];
    await cheTheiaPluginsYamlWriter.write(cheTheiaPlugins);
    // no copy of the icon
    expect(fsCopyFileSpy).toHaveBeenCalledTimes(0);
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(1, '/fake-output/v3/plugins');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(2, '/fake-output/v3/images');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(3, '/fake-output/v3/resources');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(4, '/fake-output/v3/plugins/custom-publisher/custom-name/latest');

    // icon is the default one
    const content = `schemaVersion: 1.0.0
metadata:
  id: custom-publisher/custom-name
  publisher: custom-publisher
  name: custom-name
  version: latest
  displayName: display-name
  description: my-description
  categories:
    - Programming Languages
  repository: 'http://fake-repository'
  icon: /images/default.png
sidecar:
  image: foo
dependencies:
  - my-dependency
preferences:
  foo.bar: foo
extensions:
  - 'http://my-first.vsix'
`;

    expect(fsWriteFileSpy).toHaveBeenNthCalledWith(
      1,
      '/fake-output/v3/plugins/custom-publisher/custom-name/latest/che-theia-plugin.yaml',
      content
    );
    // no version written with disable Latest
    expect(fsWriteFileSpy).toHaveBeenCalledTimes(1);
  });

  test('embed vsix', async () => {
    embedVsix = true;
    initContainer();
    cheTheiaPluginsYamlWriter = container.get(CheTheiaPluginsYamlWriter);

    const fsCopyFileSpy = jest.spyOn(fs, 'copyFile');
    const fsEnsureDirSpy = jest.spyOn(fs, 'ensureDir');
    const fsWriteFileSpy = jest.spyOn(fs, 'writeFile');

    fsEnsureDirSpy.mockReturnValue();
    fsCopyFileSpy.mockReturnValue();
    fsWriteFileSpy.mockReturnValue();
    delete cheTheiaPluginYaml.data.metadata.iconFile;
    delete cheTheiaPluginYaml.aliases;
    delete cheTheiaPluginYaml.data.dependencies;

    cheTheiaPluginYaml.data.extensions = [
      'http://fake-domain.com/folder/my.vsix',
      'https://other-fake-domain.com/subfolder/two.vsix',
      'https://another-entry.com/folder3/three.vsix',
    ];

    const cheTheiaPlugins: CheTheiaPluginYamlInfo[] = [cheTheiaPluginYaml];

    const downloadedArchive1 = '/fake-download-archive1.vsix';
    const downloadedArchive2 = '/fake-download-archive2.vsix';
    const firstVsixInfo: VsixInfo = {
      downloadedArchive: downloadedArchive1,
    } as VsixInfo;
    const secondVsixInfo: VsixInfo = {
      downloadedArchive: downloadedArchive2,
    } as VsixInfo;
    vsixInfos.set('http://fake-domain.com/folder/my.vsix', firstVsixInfo);
    vsixInfos.set('https://other-fake-domain.com/subfolder/two.vsix', secondVsixInfo);

    await cheTheiaPluginsYamlWriter.write(cheTheiaPlugins);
    // no copy of the icon
    expect(fsCopyFileSpy).toHaveBeenCalledTimes(2);
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(1, '/fake-output/v3/plugins');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(2, '/fake-output/v3/images');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(3, '/fake-output/v3/resources');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(4, '/fake-output/v3/resources/fake-domain_com/folder');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(5, '/fake-output/v3/resources/other-fake-domain_com/subfolder');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(6, '/fake-output/v3/plugins/custom-publisher/custom-name/latest');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(6, '/fake-output/v3/plugins/custom-publisher/custom-name/latest');
    // icon is the default one
    const content = `schemaVersion: 1.0.0
metadata:
  id: custom-publisher/custom-name
  publisher: custom-publisher
  name: custom-name
  version: latest
  displayName: display-name
  description: my-description
  categories:
    - Programming Languages
  repository: 'http://fake-repository'
  icon: /images/default.png
sidecar:
  image: foo
preferences:
  foo.bar: foo
extensions:
  - 'relative:extension/resources/fake-domain_com/folder/my.vsix'
  - 'relative:extension/resources/other-fake-domain_com/subfolder/two.vsix'
  - 'https://another-entry.com/folder3/three.vsix'
`;

    expect(fsWriteFileSpy).toHaveBeenNthCalledWith(
      1,
      '/fake-output/v3/plugins/custom-publisher/custom-name/latest/che-theia-plugin.yaml',
      content
    );
    // no version written with disable Latest
    expect(fsWriteFileSpy).toHaveBeenCalledTimes(1);
  });
});
