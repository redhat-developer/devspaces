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
import * as fs from 'fs-extra';
import * as path from 'path';

import { CheTheiaPluginMetaInfo } from '../../src/build';
import { VsixInfo } from '../../src/extensions/vsix-info';

export class CheTheiaPluginGenerator {
  private generatePluginMetaInfo(id: string, featured: boolean): CheTheiaPluginMetaInfo {
    const extensions: string[] = [];
    const sidecar = { image: 'foo:1234' };
    const aliases: string[] = [];
    const repository = { url: 'https://my-fake-repository', revision: 'main' };
    const vsixInfos = new Map<string, VsixInfo>();
    return { id, extensions, sidecar, aliases, repository, featured, vsixInfos };
  }

  async generate(): Promise<CheTheiaPluginMetaInfo[]> {
    const cheTheiaPlugins: CheTheiaPluginMetaInfo[] = [];

    const atlassianPackageJsonPath = path.resolve(__dirname, '..', '_data', 'packages', 'atlassian-package.json');
    const atlassianPackageJsonContent = await fs.readFile(atlassianPackageJsonPath, 'utf-8');
    const atlassianPackageJson = JSON.parse(atlassianPackageJsonContent);
    const pluginMetaInfo1 = this.generatePluginMetaInfo('atlassian', false);
    const vsixInfo1: VsixInfo = {
      uri: '/foo/atlassian-uri',
      cheTheiaPlugin: pluginMetaInfo1,
      packageJson: atlassianPackageJson,
    };
    pluginMetaInfo1.vsixInfos.set('atlassian.vsix', vsixInfo1);

    const vscodeJavaPackageJsonPath = path.resolve(__dirname, '..', '_data', 'packages', 'vscode-java-package.json');
    const vscodeJavaPackageJsonContent = await fs.readFile(vscodeJavaPackageJsonPath, 'utf-8');
    const vscodeJavaPackageJson = JSON.parse(vscodeJavaPackageJsonContent);
    const pluginMetaInfo2 = this.generatePluginMetaInfo('vscode-java', true);
    const vsixInfo2: VsixInfo = {
      uri: '/foo/vscode-java-uri',
      cheTheiaPlugin: pluginMetaInfo2,
      packageJson: vscodeJavaPackageJson,
    };
    pluginMetaInfo2.vsixInfos.set('vscode-java.vsix', vsixInfo2);

    const vscodeEmptyJson = { name: 'empty-package' } as any;
    const pluginMetaInfo3 = this.generatePluginMetaInfo('vscode-empty', true);
    const vsixInfo3: VsixInfo = {
      uri: '/foo/vscode-empty-uri',
      cheTheiaPlugin: pluginMetaInfo3,
      packageJson: vscodeEmptyJson,
    };
    pluginMetaInfo3.vsixInfos.set('vscode-empty.vsix', vsixInfo3);

    const pluginMetaInfo4 = this.generatePluginMetaInfo('vscode-no-package.json', true);
    const vsixInfo4: VsixInfo = {
      uri: '/foo/vscode-no-package-uri',
      cheTheiaPlugin: pluginMetaInfo4,
    };
    pluginMetaInfo4.vsixInfos.set('vscode-no-package-json.vsix', vsixInfo4);

    const vscodeContributesNoLanguagesJson = {
      name: 'vscode-contributers-other-than-languages',
      contributes: {
        somethingDifferent: {
          dummy: {
            foo: 'bar',
          },
        },
      },
    } as any;
    const pluginMetaInfo5 = this.generatePluginMetaInfo('vscode-contributers-other-than-languages', true);
    const vsixInfo5: VsixInfo = {
      uri: '/foo/vscode-contributers-other-than-languages-uri',
      cheTheiaPlugin: pluginMetaInfo5,
      packageJson: vscodeContributesNoLanguagesJson,
    };
    pluginMetaInfo5.vsixInfos.set('vscode-contributers-other-than-languages.vsix', vsixInfo5);

    const vscodeGoPackageJsonPath = path.resolve(__dirname, '..', '_data', 'packages', 'vscode-go-package.json');
    const vscodeGoPackageJsonContent = await fs.readFile(vscodeGoPackageJsonPath, 'utf-8');
    const vscodeGoPackageJson = JSON.parse(vscodeGoPackageJsonContent);
    const pluginMetaInfo6 = this.generatePluginMetaInfo('vscode-go', false);
    const vsixInfo6: VsixInfo = {
      uri: '/foo/vscode-go-uri',
      cheTheiaPlugin: pluginMetaInfo6,
      packageJson: vscodeGoPackageJson,
    };
    pluginMetaInfo6.vsixInfos.set('vscode-go.vsix', vsixInfo6);

    const vscodeIncompletePackageJsonPath = path.resolve(
      __dirname,
      '..',
      '_data',
      'packages',
      'incomplete-package.json'
    );
    const vscodeIncompletePackageJsonContent = await fs.readFile(vscodeIncompletePackageJsonPath, 'utf-8');
    const vscodeIncompletePackageJson = JSON.parse(vscodeIncompletePackageJsonContent);
    const pluginMetaInfo7 = this.generatePluginMetaInfo('vscode-incomplete', false);
    const vsixInfo7: VsixInfo = {
      uri: '/foo/vscode-incomplete-uri',
      cheTheiaPlugin: pluginMetaInfo7,
      packageJson: vscodeIncompletePackageJson,
    };
    pluginMetaInfo7.vsixInfos.set('vscode-incomplete.vsix', vsixInfo7);

    const vscodePartialJavaPackageJsonPath = path.resolve(
      __dirname,
      '..',
      '_data',
      'packages',
      'partial-java-without-extensions.json'
    );
    const vscodePartialJavaPackageJsonContent = await fs.readFile(vscodePartialJavaPackageJsonPath, 'utf-8');
    const vscodePartialJavaPackageJson = JSON.parse(vscodePartialJavaPackageJsonContent);
    const pluginMetaInfo8 = this.generatePluginMetaInfo('vscode-partial-java', false);
    const vsixInfo8: VsixInfo = {
      uri: '/foo/vscode-partial-java-uri',
      cheTheiaPlugin: pluginMetaInfo8,
      packageJson: vscodePartialJavaPackageJson,
    };
    pluginMetaInfo8.vsixInfos.set('vscode-incomplete.vsix', vsixInfo8);

    cheTheiaPlugins.push(
      pluginMetaInfo1,
      pluginMetaInfo2,
      pluginMetaInfo3,
      pluginMetaInfo4,
      pluginMetaInfo5,
      pluginMetaInfo6,
      pluginMetaInfo7,
      pluginMetaInfo8
    );
    return cheTheiaPlugins;
  }
}
