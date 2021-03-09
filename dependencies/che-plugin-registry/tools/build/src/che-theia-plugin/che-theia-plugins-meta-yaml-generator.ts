/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
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
import { MetaYamlPluginInfo } from '../meta-yaml/meta-yaml-plugin-info';
import { Sidecar } from '../sidecar/sidecar';

@injectable()
export class CheTheiaPluginsMetaYamlGenerator {
  @inject(Sidecar)
  private sidecar: Sidecar;

  readI18nProperty(propertyName: string, vsixInfo: VsixInfo): string {
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

  async compute(cheTheiaPlugins: CheTheiaPluginMetaInfo[]): Promise<MetaYamlPluginInfo[]> {
    // for each plugin, compute info
    const metaYamlPluginInfos: MetaYamlPluginInfo[] = await Promise.all(
      cheTheiaPlugins.map(async (chePlugin: CheTheiaPluginMetaInfo) => {
        const type = 'VS Code extension';
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

        let displayName: string;
        if (packageJson.displayName) {
          displayName = this.readI18nProperty(packageJson.displayName, firstVsix);
        } else if (packageJson.description) {
          displayName = this.readI18nProperty(packageJson.description, firstVsix);
        } else {
          displayName = name;
        }

        // title does not exist in VS Code extensions, pick up display name instead
        const title = displayName;

        let description: string;
        if (!packageJson.description) {
          description = name;
          console.error(`No description field in package.json found for ${chePluginOutput}`);
        } else {
          description = this.readI18nProperty(packageJson.description, firstVsix);
        }

        let category: VsixCategory;
        if (!packageJson.categories || packageJson.categories.length === 0) {
          console.error(`No categories field in package.json found for ${chePluginOutput}. Using Other type`);
          category = 'Other';
        } else {
          // take first category
          category = packageJson.categories[0];
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
        let firstPublicationDate: string;
        if (firstVsix.creationDate) {
          firstPublicationDate = firstVsix.creationDate;
        } else {
          console.error('No creation date');
          throw new Error(`No creation date found for vsix ${chePluginOutput}`);
        }
        const id = chePlugin.id;
        const latestUpdateDate = new Date().toISOString().slice(0, 10);
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const spec: any = {};
        if (chePlugin.sidecar) {
          const sidecarImage = await this.sidecar.getDockerImageFor(chePlugin);
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          const container: any = { image: sidecarImage };
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          let endpoints: any;
          if (chePlugin.sidecar.name) {
            container.name = chePlugin.sidecar.name;
          }
          if (chePlugin.sidecar.volumeMounts) {
            container.volumes = chePlugin.sidecar.volumeMounts.map(volume => ({
              name: volume.name,
              mountPath: volume.path,
            }));
          }
          if (chePlugin.sidecar.memoryLimit) {
            container.memoryLimit = chePlugin.sidecar.memoryLimit;
          }
          if (chePlugin.sidecar.memoryRequest) {
            container.memoryRequest = chePlugin.sidecar.memoryRequest;
          }
          if (chePlugin.sidecar.cpuRequest) {
            container.cpuRequest = chePlugin.sidecar.cpuRequest;
          }
          if (chePlugin.sidecar.cpuLimit) {
            container.cpuLimit = chePlugin.sidecar.cpuLimit;
          }
          if (chePlugin.sidecar.env) {
            container.env = chePlugin.sidecar.env;
          }
          if (chePlugin.sidecar.mountSources) {
            container.mountSources = chePlugin.sidecar.mountSources;
          }
          if (chePlugin.sidecar.args) {
            container.args = chePlugin.sidecar.args;
          }
          if (chePlugin.sidecar.command) {
            container.command = chePlugin.sidecar.command;
          }
          if (chePlugin.sidecar.endpoints) {
            // export ports
            container.ports = chePlugin.sidecar.endpoints.map(endpoint => ({ exposedPort: endpoint.targetPort }));
            endpoints = chePlugin.sidecar.endpoints;
          }

          spec.containers = [container];
          if (endpoints) {
            spec.endpoints = endpoints;
          }
        }
        spec.extensions = chePlugin.extensions;

        // grab vsix infos
        const vsixInfos = chePlugin.vsixInfos;

        const aliases = chePlugin.aliases;

        return {
          id,
          vsixInfos,
          publisher,
          name,
          version,
          type,
          displayName,
          title,
          description,
          iconFile,
          repository,
          category,
          firstPublicationDate,
          latestUpdateDate,
          spec,
          aliases,
        } as MetaYamlPluginInfo;
      })
    );

    return metaYamlPluginInfos;
  }
}
