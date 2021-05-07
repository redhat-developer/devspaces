/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/

import * as moment from 'moment';
import * as ora from 'ora';
import * as path from 'path';

import { inject, injectable, named } from 'inversify';

import { CheEditorMetaInfo } from './editor/che-editors-meta-info';
import { CheEditorYaml } from './editor/che-editors-yaml';
import { CheEditorsAnalyzer } from './editor/che-editors-analyzer';
import { CheEditorsMetaYamlGenerator } from './editor/che-editors-meta-yaml-generator';
import { ChePluginMetaInfo } from './che-plugin/che-plugins-meta-info';
import { ChePluginYaml } from './che-plugin/che-plugins-yaml';
import { ChePluginsAnalyzer } from './che-plugin/che-plugins-analyzer';
import { ChePluginsMetaYamlGenerator } from './che-plugin/che-plugins-meta-yaml-generator';
import { CheTheiaPluginAnalyzerMetaInfo } from './che-theia-plugin/che-theia-plugin-analyzer-meta-info';
import { CheTheiaPluginYaml } from './che-theia-plugin/che-theia-plugins-yaml';
import { CheTheiaPluginsAnalyzer } from './che-theia-plugin/che-theia-plugins-analyzer';
import { CheTheiaPluginsMetaYamlGenerator } from './che-theia-plugin/che-theia-plugins-meta-yaml-generator';
import { CheTheiaPluginsYamlGenerator } from './che-theia-plugin/che-theia-plugins-yaml-generator';
import { CheTheiaPluginsYamlWriter } from './che-theia-plugin/che-theia-plugins-yaml-writer';
import { Deferred } from './util/deferred';
import { DigestImagesHelper } from './meta-yaml/digest-images-helper';
import { ExternalImagesWriter } from './meta-yaml/external-images-writer';
import { FeaturedAnalyzer } from './featured/featured-analyzer';
import { FeaturedWriter } from './featured/featured-writer';
import { IndexWriter } from './meta-yaml/index-writer';
import { MetaYamlWriter } from './meta-yaml/meta-yaml-writer';
import { RecommendationsAnalyzer } from './recommendations/recommendations-analyzer';
import { RecommendationsWriter } from './recommendations/recommendations-writer';
import { VsixInfo } from './extensions/vsix-info';
import { VsixUrlAnalyzer } from './extensions/vsix-url-analyzer';

export interface MetaYamlSpec {
  extensions: string[];
}
export interface MetaYaml {
  name: string;
  version: string;
  publisher: string;
  spec: MetaYamlSpec;
}

export interface CheTheiaPluginMetaInfo extends CheTheiaPluginAnalyzerMetaInfo {
  id: string;
}

@injectable()
export class Build {
  @inject('string[]')
  @named('ARGUMENTS')
  private args: string[];

  @inject('string')
  @named('PLUGIN_REGISTRY_ROOT_DIRECTORY')
  private pluginRegistryRootDirectory: string;

  @inject('string')
  @named('OUTPUT_ROOT_DIRECTORY')
  private outputRootDirectory: string;

  @inject('boolean')
  @named('SKIP_DIGEST_GENERATION')
  private skipDigests: boolean;

  @inject(FeaturedAnalyzer)
  private featuredAnalyzer: FeaturedAnalyzer;

  @inject(CheTheiaPluginsMetaYamlGenerator)
  private cheTheiaPluginsMetaYamlGenerator: CheTheiaPluginsMetaYamlGenerator;

  @inject(CheTheiaPluginsYamlGenerator)
  private cheTheiaPluginsYamlGenerator: CheTheiaPluginsYamlGenerator;

  @inject(CheEditorsMetaYamlGenerator)
  private cheEditorsMetaYamlGenerator: CheEditorsMetaYamlGenerator;

  @inject(ChePluginsMetaYamlGenerator)
  private chePluginsMetaYamlGenerator: ChePluginsMetaYamlGenerator;

  @inject(MetaYamlWriter)
  private metaYamlWriter: MetaYamlWriter;

  @inject(CheTheiaPluginsYamlWriter)
  private cheTheiaPluginsYamlWriter: CheTheiaPluginsYamlWriter;

  @inject(ExternalImagesWriter)
  private externalImagesWriter: ExternalImagesWriter;

  @inject(IndexWriter)
  private indexWriter: IndexWriter;

  @inject(DigestImagesHelper)
  private digestImagesHelper: DigestImagesHelper;

  @inject(FeaturedWriter)
  private featuredWriter: FeaturedWriter;

  @inject(RecommendationsAnalyzer)
  private recommendationsAnalyzer: RecommendationsAnalyzer;

  @inject(RecommendationsWriter)
  private recommendationsWriter: RecommendationsWriter;

  @inject(VsixUrlAnalyzer)
  private vsixUrlAnalyzer: VsixUrlAnalyzer;

  @inject(CheTheiaPluginsAnalyzer)
  private cheTheiaPluginsAnalyzer: CheTheiaPluginsAnalyzer;

  @inject(CheEditorsAnalyzer)
  private cheEditorsAnalyzer: CheEditorsAnalyzer;

  @inject(ChePluginsAnalyzer)
  private chePluginsAnalyzer: ChePluginsAnalyzer;

  public async analyzeCheTheiaPlugin(
    cheTheiaPlugin: CheTheiaPluginAnalyzerMetaInfo,
    vsixExtensionUri: string
  ): Promise<void> {
    const vsixInfo = {
      uri: vsixExtensionUri,
      cheTheiaPlugin,
    };
    cheTheiaPlugin.vsixInfos.set(vsixExtensionUri, vsixInfo);
    await this.vsixUrlAnalyzer.analyze(vsixInfo);
  }

  updateTask<T>(promise: Promise<T>, task: ora.Ora, success: { (): void }, failureMessage: string): void {
    promise.then(success, () => task.fail(failureMessage));
  }

  /**
   * Analyze che-theia-plugins.yaml and download all related vsix files
   */
  protected async analyzeCheTheiaPluginsYaml(): Promise<CheTheiaPluginMetaInfo[]> {
    const cheTheiaPluginsPath = path.resolve(this.pluginRegistryRootDirectory, 'che-theia-plugins.yaml');
    const cheTheiaPluginsYaml = await this.wrapIntoTask(
      'Read che-theia-plugins.yaml file',
      this.cheTheiaPluginsAnalyzer.analyze(cheTheiaPluginsPath)
    );

    // First, parse che-theia-plugins yaml
    const analyzingCheTheiaPlugins: CheTheiaPluginAnalyzerMetaInfo[] = await Promise.all(
      cheTheiaPluginsYaml.plugins.map(async (cheTheiaPluginYaml: CheTheiaPluginYaml) => {
        const extension = cheTheiaPluginYaml.extension;
        const vsixInfos = new Map<string, VsixInfo>();
        const id = cheTheiaPluginYaml.id;
        const featured = cheTheiaPluginYaml.featured || false;
        const aliases = cheTheiaPluginYaml.aliases || [];
        const preferences = cheTheiaPluginYaml.preferences;
        const sidecar = cheTheiaPluginYaml.sidecar;
        const repository = cheTheiaPluginYaml.repository;
        const metaYaml = cheTheiaPluginYaml.metaYaml;
        const extraDependencies = cheTheiaPluginYaml.extraDependencies;
        const skipDependencies = cheTheiaPluginYaml.skipDependencies;
        return {
          id,
          sidecar,
          preferences,
          aliases,
          extension,
          metaYaml,
          extraDependencies,
          skipDependencies,
          featured,
          vsixInfos,
          repository,
        };
      })
    );

    let current = 0;
    // analyze vsix of each che-theia plug-in
    const title = 'Download/Unpack/Analyze CheTheiaPlugins in parallel (may take a while)';
    const downloadAndAnalyzeTask = ora(title).start();
    const deferred = new Deferred();
    this.wrapIntoTask(title, deferred.promise, downloadAndAnalyzeTask);
    await Promise.all(
      analyzingCheTheiaPlugins.map(async cheTheiaPlugin => {
        if (!cheTheiaPlugin.extension) {
          throw new Error(`The plugin ${JSON.stringify(cheTheiaPlugin)} does not have mandatory extension field`);
        }
        console.log('Analyzing ' + cheTheiaPlugin.extension);
        const analyzePromise = this.analyzeCheTheiaPlugin(cheTheiaPlugin, cheTheiaPlugin.extension);
        this.updateTask(
          analyzePromise,
          downloadAndAnalyzeTask,
          () => {
            current++;
            downloadAndAnalyzeTask.text = `${title} [${current}/${analyzingCheTheiaPlugins.length}] ...`;
          },
          `Error analyzing extension ${cheTheiaPlugin.extension} from ${cheTheiaPlugin.repository.url}`
        );

        return analyzePromise;
      })
    );
    deferred.resolve();

    // now need to add ids (if not existing) in the analyzed plug-ins
    const analyzingCheTheiaPluginsWithIds: CheTheiaPluginMetaInfo[] = analyzingCheTheiaPlugins.map(plugin => {
      let id: string;
      if (plugin.id) {
        id = plugin.id;
      } else {
        // need to compute id
        const vsixDetails = plugin.vsixInfos.get(plugin.extension);
        const packageInfo = vsixDetails?.packageJson;
        if (!packageInfo) {
          throw new Error(`Unable to find a package.json file for extension ${plugin.extension}`);
        }
        const publisher = packageInfo.publisher;
        if (!publisher) {
          throw new Error(`Unable to find a publisher field in package.json file for extension ${plugin.extension}`);
        }
        const name = packageInfo.name;
        if (!name) {
          throw new Error(`Unable to find a name field in package.json file for extension ${plugin.extension}`);
        }
        id = `${publisher}/${name}`.toLowerCase();
      }

      return { ...plugin, id };
    });

    return analyzingCheTheiaPluginsWithIds;
  }

  /**
   * Analyze che-editors.yaml
   */
  protected async analyzeCheEditorsYaml(): Promise<CheEditorMetaInfo[]> {
    const cheEditorsPath = path.resolve(this.pluginRegistryRootDirectory, 'che-editors.yaml');
    const cheEditorsYaml = await this.cheEditorsAnalyzer.analyze(cheEditorsPath);

    // First, parse che-editors yaml
    const cheEditors: CheEditorMetaInfo[] = await Promise.all(
      cheEditorsYaml.editors.map(async (cheEditorYaml: CheEditorYaml) => {
        const cheEditorMetaInfo: CheEditorMetaInfo = { ...cheEditorYaml };
        return cheEditorMetaInfo;
      })
    );

    return cheEditors;
  }

  /**
   * Analyze che-plugins.yaml
   */
  protected async analyzeChePluginsYaml(): Promise<ChePluginMetaInfo[]> {
    const chePluginsPath = path.resolve(this.pluginRegistryRootDirectory, 'che-plugins.yaml');
    const chePluginsYaml = await this.chePluginsAnalyzer.analyze(chePluginsPath);

    // First, parse che-plugins yaml
    const chePlugins: ChePluginMetaInfo[] = await Promise.all(
      chePluginsYaml.plugins.map(async (chePluginYaml: ChePluginYaml) => {
        const chePluginMetaInfo: ChePluginMetaInfo = { ...chePluginYaml };
        return chePluginMetaInfo;
      })
    );

    // update editors
    return chePlugins;
  }

  async wrapIntoTask<T>(title: string, promise: Promise<T>, customTask?: ora.Ora): Promise<T> {
    let task: ora.Ora;
    if (customTask) {
      task = customTask;
    } else {
      task = ora(title).start();
    }
    if (promise) {
      promise.then(
        () => task.succeed(),
        () => task.fail()
      );
    }
    return promise;
  }

  public async build(): Promise<void> {
    const start = moment();

    // analyze the che-theia-plugins.yaml yaml file
    const cheTheiaPlugins = await this.analyzeCheTheiaPluginsYaml();

    const cheTheiaPluginsMetaYaml = await this.wrapIntoTask(
      'Compute meta.yaml for che-theia-plugins',
      this.cheTheiaPluginsMetaYamlGenerator.compute(cheTheiaPlugins)
    );
    const cheTheiaPluginsYaml = await this.wrapIntoTask(
      'Compute che-theia-plugin.yaml fragments for che-theia-plugins',
      this.cheTheiaPluginsYamlGenerator.compute(cheTheiaPlugins)
    );

    const cheEditors = await this.wrapIntoTask('Analyze che-editors.yaml file', this.analyzeCheEditorsYaml());
    const cheEditorsMetaYaml = await this.wrapIntoTask(
      'Compute meta.yaml for che-editors',
      this.cheEditorsMetaYamlGenerator.compute(cheEditors)
    );

    const chePlugins = await this.wrapIntoTask('Analyze che-plugins.yaml file', this.analyzeChePluginsYaml());

    const chePluginsMetaYaml = await this.wrapIntoTask(
      'Compute meta.yaml for che-plugins',
      this.chePluginsMetaYamlGenerator.compute(chePlugins)
    );

    const computedYamls = [...cheTheiaPluginsMetaYaml, ...cheEditorsMetaYaml, ...chePluginsMetaYaml];

    let allMetaYamls = computedYamls;
    if (!this.skipDigests) {
      // update all images to use digest instead of tags
      allMetaYamls = await this.wrapIntoTask(
        'Update tags by digests for OCI images',
        this.digestImagesHelper.updateImages(computedYamls)
      );
    }

    // generate v3/external_images.txt
    await this.wrapIntoTask('Generate v3/external_images.txt', this.externalImagesWriter.write(allMetaYamls));

    // generate v3/plugins folder
    const generatedYamls = await this.wrapIntoTask(
      'Write meta.yamls in v3/plugins folder',
      this.metaYamlWriter.write(allMetaYamls)
    );

    // write che-theia-plugins fragment
    await this.wrapIntoTask(
      'Write che-theia-plugin.yaml fragment in v3/plugins folder',
      this.cheTheiaPluginsYamlWriter.write(cheTheiaPluginsYaml)
    );

    // generate index.json
    await this.wrapIntoTask('Generate v3/plugins/index.json file', this.indexWriter.write(generatedYamls));

    // generate featured.json
    const jsonOutput = await this.wrapIntoTask(
      'Generates Che-Theia featured.json file',
      this.featuredAnalyzer.generate(cheTheiaPlugins)
    );
    await this.wrapIntoTask('Write Che-Theia featured.json file', this.featuredWriter.writeReport(jsonOutput));

    // generate Recommendations
    const recommendations = await this.wrapIntoTask(
      'Generate Che-Theia recommendations files',
      this.recommendationsAnalyzer.generate(cheTheiaPlugins)
    );
    await this.wrapIntoTask(
      'Write Che-Theia recommentations files',
      this.recommendationsWriter.writeRecommendations(recommendations)
    );

    const end = moment();
    const duration = moment.duration(start.diff(end)).humanize();
    console.log(`🎉 Successfully generated in ${this.outputRootDirectory}. Took ${duration}.`);
  }
}
