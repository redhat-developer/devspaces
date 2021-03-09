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

import * as fs from 'fs-extra';
import * as moment from 'moment';

import { Container } from 'inversify';
import { MetaYamlPluginInfo } from '../../src/meta-yaml/meta-yaml-plugin-info';
import { MetaYamlToDevfileYaml } from '../../src/devfile/meta-yaml-to-devfile-yaml';
import { MetaYamlWriter } from '../../src/meta-yaml/meta-yaml-writer';
import { VsixInfo } from '../../src/extensions/vsix-info';

describe('Test MetaYamlWriter', () => {
  let container: Container;

  let metaPluginYaml: MetaYamlPluginInfo;
  let metaYamlWriter: MetaYamlWriter;
  const latestUpdateDate = moment.utc().format('YYYY-MM-DD');
  let embedVsix = false;
  const vsixInfos = new Map<string, VsixInfo>();

  const metaYamlToDevfileYamlConvertMethod = jest.fn();
  const metaYamlToDevfileYaml = {
    convert: metaYamlToDevfileYamlConvertMethod,
  } as any;

  function initContainer() {
    container = new Container();
    container.bind('string').toConstantValue('/fake-output').whenTargetNamed('OUTPUT_ROOT_DIRECTORY');
    container.bind('boolean').toConstantValue(embedVsix).whenTargetNamed('EMBED_VSIX');
    container.bind(MetaYamlToDevfileYaml).toConstantValue(metaYamlToDevfileYaml);

    container.bind(MetaYamlWriter).toSelf().inSingletonScope();
  }

  beforeEach(() => {
    vsixInfos.clear();
    metaPluginYaml = {
      id: 'custom-publisher/custom-name',
      aliases: ['first/alias', 'second/alias'],
      publisher: 'my-publisher',
      name: 'my-name',
      version: 'my-version',
      type: 'VS Code extension',
      displayName: 'display-name',
      title: 'my-title',
      description: 'my-description',
      iconFile: '/fake-dir/icon.png',
      category: 'Programming Languages',
      repository: 'http://fake-repository',
      firstPublicationDate: '2019-01-01',
      latestUpdateDate,
      vsixInfos,
      spec: {
        extensions: ['http://my-first.vsix'],
      },
    };
    jest.restoreAllMocks();
    jest.resetAllMocks();
    initContainer();
    metaYamlWriter = container.get(MetaYamlWriter);
  });

  test('basics', async () => {
    const fsCopyFileSpy = jest.spyOn(fs, 'copyFile');
    const fsEnsureDirSpy = jest.spyOn(fs, 'ensureDir');
    const fsWriteFileSpy = jest.spyOn(fs, 'writeFile');

    fsEnsureDirSpy.mockReturnValue();
    fsCopyFileSpy.mockReturnValue();
    fsWriteFileSpy.mockReturnValue();

    const metaYamlPlugins: MetaYamlPluginInfo[] = [metaPluginYaml];
    const metaYalResults = await metaYamlWriter.write(metaYamlPlugins);
    expect(metaYalResults.length).toBe(3);
    expect(metaYalResults[0].id).toBe('custom-publisher/custom-name/latest');
    expect(metaYalResults[1].id).toBe('first/alias/latest');
    expect(metaYalResults[2].id).toBe('second/alias/latest');

    expect(fsCopyFileSpy).toHaveBeenCalledWith(
      '/fake-dir/icon.png',
      '/fake-output/v3/images/my-publisher-my-name-icon.png'
    );
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(1, '/fake-output/v3/plugins');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(2, '/fake-output/v3/images');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(3, '/fake-output/v3/resources');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(4, '/fake-output/v3/plugins/custom-publisher/custom-name/latest');
    const content = `apiVersion: v2
publisher: custom-publisher
name: custom-name
version: latest
type: VS Code extension
displayName: display-name
title: my-title
description: my-description
icon: /v3/images/my-publisher-my-name-icon.png
category: Programming Languages
repository: 'http://fake-repository'
firstPublicationDate: '2019-01-01'
latestUpdateDate: '${latestUpdateDate}'
spec:
  extensions:
    - 'http://my-first.vsix'
`;
    expect(fsWriteFileSpy).toHaveBeenNthCalledWith(
      1,
      '/fake-output/v3/plugins/custom-publisher/custom-name/latest/meta.yaml',
      content
    );

    // check that alias is also being written (and alias is deprecated)
    const aliasContent = content
      .replace('custom-publisher', 'first')
      .replace('custom-name', 'alias')
      .replace('spec:\n', 'deprecate:\n  automigrate: true\n  migrateTo: custom-publisher/custom-name/latest\nspec:\n');
    expect(fsWriteFileSpy).toHaveBeenNthCalledWith(
      2,
      '/fake-output/v3/plugins/first/alias/latest/meta.yaml',
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
    delete metaPluginYaml.iconFile;
    delete metaPluginYaml.aliases;
    metaPluginYaml.disableLatest = true;
    const metaYamlPlugins: MetaYamlPluginInfo[] = [metaPluginYaml];
    await metaYamlWriter.write(metaYamlPlugins);
    // no copy of the icon
    expect(fsCopyFileSpy).toHaveBeenCalledTimes(0);
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(1, '/fake-output/v3/plugins');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(2, '/fake-output/v3/images');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(3, '/fake-output/v3/resources');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(
      4,
      '/fake-output/v3/plugins/custom-publisher/custom-name/my-version'
    );
    // icon is the default one
    const content = `apiVersion: v2
publisher: custom-publisher
name: custom-name
version: my-version
type: VS Code extension
displayName: display-name
title: my-title
description: my-description
icon: /v3/images/eclipse-che-logo.png
category: Programming Languages
repository: 'http://fake-repository'
firstPublicationDate: '2019-01-01'
latestUpdateDate: '${latestUpdateDate}'
spec:
  extensions:
    - 'http://my-first.vsix'
`;

    expect(fsWriteFileSpy).toHaveBeenNthCalledWith(
      1,
      '/fake-output/v3/plugins/custom-publisher/custom-name/my-version/meta.yaml',
      content
    );
    // no version written with disable Latest
    expect(fsWriteFileSpy).toHaveBeenCalledTimes(1);
  });

  test('embed vsix', async () => {
    embedVsix = true;
    initContainer();
    metaYamlWriter = container.get(MetaYamlWriter);

    const fsCopyFileSpy = jest.spyOn(fs, 'copyFile');
    const fsEnsureDirSpy = jest.spyOn(fs, 'ensureDir');
    const fsWriteFileSpy = jest.spyOn(fs, 'writeFile');

    fsEnsureDirSpy.mockReturnValue();
    fsCopyFileSpy.mockReturnValue();
    fsWriteFileSpy.mockReturnValue();
    delete metaPluginYaml.iconFile;
    delete metaPluginYaml.aliases;
    metaPluginYaml.disableLatest = true;

    metaPluginYaml.spec.extensions = [
      'http://fake-domain.com/folder/my.vsix',
      'https://other-fake-domain.com/subfolder/two.vsix',
      'https://another-entry.com/folder3/three.vsix',
    ];

    const metaYamlPlugins: MetaYamlPluginInfo[] = [metaPluginYaml];

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
    await metaYamlWriter.write(metaYamlPlugins);
    // no copy of the icon
    expect(fsCopyFileSpy).toHaveBeenCalledTimes(2);
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(1, '/fake-output/v3/plugins');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(2, '/fake-output/v3/images');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(3, '/fake-output/v3/resources');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(4, '/fake-output/v3/resources/fake-domain_com/folder');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(5, '/fake-output/v3/resources/other-fake-domain_com/subfolder');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(
      6,
      '/fake-output/v3/plugins/custom-publisher/custom-name/my-version'
    );
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(
      6,
      '/fake-output/v3/plugins/custom-publisher/custom-name/my-version'
    );
    // icon is the default one
    const content = `apiVersion: v2
publisher: custom-publisher
name: custom-name
version: my-version
type: VS Code extension
displayName: display-name
title: my-title
description: my-description
icon: /v3/images/eclipse-che-logo.png
category: Programming Languages
repository: 'http://fake-repository'
firstPublicationDate: '2019-01-01'
latestUpdateDate: '${latestUpdateDate}'
spec:
  extensions:
    - 'relative:extension/resources/fake-domain_com/folder/my.vsix'
    - 'relative:extension/resources/other-fake-domain_com/subfolder/two.vsix'
    - 'https://another-entry.com/folder3/three.vsix'
`;

    expect(fsWriteFileSpy).toHaveBeenNthCalledWith(
      1,
      '/fake-output/v3/plugins/custom-publisher/custom-name/my-version/meta.yaml',
      content
    );
    // no version written with disable Latest
    expect(fsWriteFileSpy).toHaveBeenCalledTimes(1);
  });

  test('embed vsix with extensions', async () => {
    embedVsix = true;
    initContainer();
    metaYamlWriter = container.get(MetaYamlWriter);

    const fsCopyFileSpy = jest.spyOn(fs, 'copyFile');
    const fsEnsureDirSpy = jest.spyOn(fs, 'ensureDir');
    const fsWriteFileSpy = jest.spyOn(fs, 'writeFile');

    fsEnsureDirSpy.mockReturnValue();
    fsCopyFileSpy.mockReturnValue();
    fsWriteFileSpy.mockReturnValue();
    delete metaPluginYaml.iconFile;
    delete metaPluginYaml.aliases;
    metaPluginYaml.disableLatest = true;

    metaPluginYaml.spec.extensions = [
      'http://fake-domain.com/folder/my.vsix',
      'https://other-fake-domain.com/subfolder/two.vsix',
      'https://another-entry.com/folder3/three.vsix',
    ];

    const metaYamlPlugins: MetaYamlPluginInfo[] = [metaPluginYaml];

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
    await metaYamlWriter.write(metaYamlPlugins);
    // no copy of the icon
    expect(fsCopyFileSpy).toHaveBeenCalledTimes(2);
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(1, '/fake-output/v3/plugins');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(2, '/fake-output/v3/images');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(3, '/fake-output/v3/resources');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(4, '/fake-output/v3/resources/fake-domain_com/folder');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(5, '/fake-output/v3/resources/other-fake-domain_com/subfolder');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(
      6,
      '/fake-output/v3/plugins/custom-publisher/custom-name/my-version'
    );
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(
      6,
      '/fake-output/v3/plugins/custom-publisher/custom-name/my-version'
    );
    // icon is the default one
    const content = `apiVersion: v2
publisher: custom-publisher
name: custom-name
version: my-version
type: VS Code extension
displayName: display-name
title: my-title
description: my-description
icon: /v3/images/eclipse-che-logo.png
category: Programming Languages
repository: 'http://fake-repository'
firstPublicationDate: '2019-01-01'
latestUpdateDate: '${latestUpdateDate}'
spec:
  extensions:
    - 'relative:extension/resources/fake-domain_com/folder/my.vsix'
    - 'relative:extension/resources/other-fake-domain_com/subfolder/two.vsix'
    - 'https://another-entry.com/folder3/three.vsix'
`;

    expect(fsWriteFileSpy).toHaveBeenNthCalledWith(
      1,
      '/fake-output/v3/plugins/custom-publisher/custom-name/my-version/meta.yaml',
      content
    );
    // no version written with disable Latest
    expect(fsWriteFileSpy).toHaveBeenCalledTimes(1);
  });

  test('embed vsix without extensions', async () => {
    embedVsix = true;
    initContainer();
    metaYamlWriter = container.get(MetaYamlWriter);

    const fsCopyFileSpy = jest.spyOn(fs, 'copyFile');
    const fsEnsureDirSpy = jest.spyOn(fs, 'ensureDir');
    const fsWriteFileSpy = jest.spyOn(fs, 'writeFile');

    fsEnsureDirSpy.mockReturnValue();
    fsCopyFileSpy.mockReturnValue();
    fsWriteFileSpy.mockReturnValue();
    delete metaPluginYaml.iconFile;
    delete metaPluginYaml.aliases;
    metaPluginYaml.disableLatest = true;

    metaPluginYaml.spec = {} as any;

    const metaYamlPlugins: MetaYamlPluginInfo[] = [metaPluginYaml];

    await metaYamlWriter.write(metaYamlPlugins);
    // no copy of the icon
    expect(fsCopyFileSpy).toHaveBeenCalledTimes(0);
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(1, '/fake-output/v3/plugins');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(2, '/fake-output/v3/images');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(3, '/fake-output/v3/resources');
    expect(fsEnsureDirSpy).toHaveBeenNthCalledWith(
      4,
      '/fake-output/v3/plugins/custom-publisher/custom-name/my-version'
    );
    // icon is the default one
    const content = `apiVersion: v2
publisher: custom-publisher
name: custom-name
version: my-version
type: VS Code extension
displayName: display-name
title: my-title
description: my-description
icon: /v3/images/eclipse-che-logo.png
category: Programming Languages
repository: 'http://fake-repository'
firstPublicationDate: '2019-01-01'
latestUpdateDate: '${latestUpdateDate}'
spec: {}
`;

    expect(fsWriteFileSpy).toHaveBeenNthCalledWith(
      1,
      '/fake-output/v3/plugins/custom-publisher/custom-name/my-version/meta.yaml',
      content
    );
    // no version written with disable Latest
    expect(fsWriteFileSpy).toHaveBeenCalledTimes(1);
  });

  test('meta yaml --> devfile yaml', async () => {
    initContainer();
    metaYamlWriter = container.get(MetaYamlWriter);

    const fsCopyFileSpy = jest.spyOn(fs, 'copyFile');
    const fsEnsureDirSpy = jest.spyOn(fs, 'ensureDir');
    const fsWriteFileSpy = jest.spyOn(fs, 'writeFile');

    fsEnsureDirSpy.mockReturnValue();
    fsCopyFileSpy.mockReturnValue();
    fsWriteFileSpy.mockReturnValue();

    metaPluginYaml = {
      apiVersion: 'v2',
      id: 'foo/bar',
      publisher: 'foo',
      name: 'bar',
      version: '0.0.1',
      displayName: 'minimal-endpoint',
      title: 'minimal-endpoint',
      description: 'minimal-endpoint',
      icon: '/v3/images/eclipse-che-logo.png',
      category: 'Other',
      repository: 'http://fake-repository',
      firstPublicationDate: '2019-01-01',
      latestUpdateDate,
      type: 'Che Plugin',
      spec: {
        endpoints: [
          {
            name: 'www',
            targetPort: 3100,
          },
        ],
        containers: [
          {
            name: 'minimal-endpoint',
            image: 'quay.io/minimal-endpoint',
          },
        ],
      },
    } as any;

    const metaYamlPlugins: MetaYamlPluginInfo[] = [metaPluginYaml];
    metaYamlToDevfileYamlConvertMethod.mockReturnValue({ devfileFakeResult: 'dummy' });
    await metaYamlWriter.write(metaYamlPlugins);

    expect(fsWriteFileSpy).toHaveBeenCalledTimes(2);

    expect(fsWriteFileSpy).toHaveBeenNthCalledWith(
      2,
      '/fake-output/v3/plugins/foo/bar/latest/devfile.yaml',
      'devfileFakeResult: dummy\n'
    );
  });
});
