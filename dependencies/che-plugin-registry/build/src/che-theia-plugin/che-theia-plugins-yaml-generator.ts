/**********************************************************************
 * Copyright (c) 2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
import * as path from 'path';

import { VsixCategory, VsixInfo } from '../extensions/vsix-info';
import { inject, injectable } from 'inversify';

import { CheTheiaPluginMetaInfo } from '../build';
import { CheTheiaPluginYamlInfo } from './che-theia-plugin-yaml-info';
import { Sidecar } from '../sidecar/sidecar';

@injectable()
export class CheTheiaPluginsYamlGenerator {
  static readonly CHE_THEIA_SIDECAR_PREFERENCES = 'CHE_THEIA_SIDECAR_PREFERENCES';

  @inject(Sidecar)
  private sidecar: Sidecar;

  readI18nProperty(propertyName: string | undefined, vsixInfo: VsixInfo): string {
    if (!propertyName) {
      return '';
    }
    if (propertyName && propertyName.startsWith('%') && propertyName.endsWith('%')) {
      const propertyWithoutPrefixSuffix = propertyName.substring(1, propertyName.length - 1);
      // need to look if there is i18n
      const nls = vsixInfo.packageNlsJson;
      if (nls) {
        return nls[propertyWithoutPrefixSuffix];
      }
    }
    return propertyName;
  }

  async compute(cheTheiaPlugins: CheTheiaPluginMetaInfo[]): Promise<CheTheiaPluginYamlInfo[]> {
    // for each plugin, compute info
    const yamlPluginInfos: CheTheiaPluginYamlInfo[] = await Promise.all(
      cheTheiaPlugins.map(async (chePlugin: CheTheiaPluginMetaInfo) => {
        const vsixData = Array.from(chePlugin.vsixInfos.values());
        const firstVsix = vsixData[0];
        const packageJson = firstVsix.packageJson;

        const chePluginOutput = JSON.stringify(chePlugin);

        if (!packageJson) {
          throw new Error(`No package.json found for ${chePluginOutput}`);
        }
        if (!packageJson.publisher) {
          throw new Error(`No publisher field in package.json found for ${chePluginOutput}`);
        }
        const publisher: string = packageJson.publisher.toLowerCase();
        if (!packageJson.name) {
          throw new Error(`No name field in package.json found for ${chePluginOutput}`);
        }
        const name: string = packageJson.name.toLowerCase();

        if (!packageJson.version) {
          throw new Error(`No version field in package.json found for ${chePluginOutput}`);
        }
        const version: string = packageJson.version;

        const displayName: string = this.readI18nProperty(packageJson.displayName, firstVsix);

        const description = this.readI18nProperty(packageJson.description, firstVsix);

        let categories: VsixCategory[];
        if (!packageJson.categories || packageJson.categories.length === 0) {
          console.error(`No categories field in package.json found for ${chePluginOutput}. Using Other type`);
          categories = ['Other'];
        } else {
          // take first category
          categories = packageJson.categories;
        }

        if (!packageJson.icon) {
          console.warn(`No icon field in package.json found for ${chePluginOutput}`);
        }
        let iconFile: string | undefined;
        if (packageJson.icon && firstVsix.unpackedExtensionRootDir) {
          iconFile = path.resolve(firstVsix.unpackedExtensionRootDir, packageJson.icon);
        }

        let repository: string;
        if (packageJson.repository && typeof packageJson.repository === 'string') {
          repository = packageJson.repository;
        } else if (
          packageJson.repository &&
          packageJson.repository.url &&
          typeof packageJson.repository.url === 'string'
        ) {
          repository = packageJson.repository.url;
        } else {
          // take definition from the yaml
          repository = chePlugin.repository.url;
          console.warn(
            `repository field is not a string or repository.url missing in package.json found, using the one from yaml content for ${chePluginOutput}`
          );
        }

        const id = chePlugin.id;

        const preferences = chePlugin.preferences;

        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        let sidecarContainer: any;

        // add the plugin extension
        const extensions = [chePlugin.extension];

        // now, do we have dependencies ?
        let dependencies = [];

        const packageJsonDependencies = packageJson.extensionDependencies;
        if (packageJsonDependencies && packageJsonDependencies.length > 0) {
          dependencies.push(
            ...packageJsonDependencies.map(dependency => dependency.replace('.', '/').toLocaleLowerCase())
          );
        }

        const skipDependencies = chePlugin.skipDependencies || [];
        const extraDependencies = chePlugin.extraDependencies || [];

        if (chePlugin.metaYaml) {
          // extra dependencies ?
          const metaYamlExtraDependencies = chePlugin.metaYaml.extraDependencies || [];
          extraDependencies.push(...metaYamlExtraDependencies);
          dependencies.push(...extraDependencies);

          // remove dependencies to ignore
          const metaYamlSkipDependencies = chePlugin.metaYaml.skipDependencies || [];
          skipDependencies.push(...metaYamlSkipDependencies);
          dependencies = dependencies.filter(dependency => !skipDependencies.includes(dependency));
        }

        // now that we have list of all dependencies, grab extensions from these one and inline them
        if (dependencies.length > 0) {
          // remove all 'builtin' except typescript
          dependencies = dependencies.filter(
            dependency => dependency === 'vscode/typescript-language-features' || !dependency.startsWith('vscode/')
          );

          // get unique elements
          dependencies = [...new Set(dependencies)].sort();
        }

        // list of vsix
        const vsixInfos = chePlugin.vsixInfos;

        if (chePlugin.sidecar) {
          const sidecarImage = await this.sidecar.getDockerImageFor(chePlugin);
          sidecarContainer = { ...chePlugin.sidecar, image: sidecarImage };
          // remove definition of the docker image source folder
          delete sidecarContainer.directory;
        }

        return {
          aliases: chePlugin.aliases,
          vsixInfos,
          data: {
            schemaVersion: '1.0.0',
            metadata: {
              id,
              publisher,
              name,
              version,
              displayName,
              description,
              iconFile,
              repository,
              categories,
            },
            sidecar: sidecarContainer,
            preferences,
            dependencies,
            extensions,
          },
        };
      })
    );

    return yamlPluginInfos;
  }
}
