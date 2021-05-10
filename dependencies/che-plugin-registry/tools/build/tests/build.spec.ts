/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
import 'reflect-metadata';

import * as ora from 'ora';

import { CheEditorYaml, CheEditorsYaml } from '../src/editor/che-editors-yaml';
import { ChePluginYaml, ChePluginsYaml } from '../src/che-plugin/che-plugins-yaml';
import { CheTheiaPluginYaml, CheTheiaPluginsYaml } from '../src/che-theia-plugin/che-theia-plugins-yaml';

import { Build } from '../src/build';
import { CheEditorsAnalyzer } from '../src/editor/che-editors-analyzer';
import { CheEditorsMetaYamlGenerator } from '../src/editor/che-editors-meta-yaml-generator';
import { ChePluginsAnalyzer } from '../src/che-plugin/che-plugins-analyzer';
import { ChePluginsMetaYamlGenerator } from '../src/che-plugin/che-plugins-meta-yaml-generator';
import { CheTheiaPluginAnalyzerMetaInfo } from '../src/che-theia-plugin/che-theia-plugin-analyzer-meta-info';
import { CheTheiaPluginsAnalyzer } from '../src/che-theia-plugin/che-theia-plugins-analyzer';
import { CheTheiaPluginsMetaYamlGenerator } from '../src/che-theia-plugin/che-theia-plugins-meta-yaml-generator';
import { CheTheiaPluginsYamlGenerator } from '../src/che-theia-plugin/che-theia-plugins-yaml-generator';
import { CheTheiaPluginsYamlWriter } from '../src/che-theia-plugin/che-theia-plugins-yaml-writer';
import { Container } from 'inversify';
import { Deferred } from '../src/util/deferred';
import { DigestImagesHelper } from '../src/meta-yaml/digest-images-helper';
import { ExternalImagesWriter } from '../src/meta-yaml/external-images-writer';
import { FeaturedAnalyzer } from '../src/featured/featured-analyzer';
import { FeaturedWriter } from '../src/featured/featured-writer';
import { IndexWriter } from '../src/meta-yaml/index-writer';
import { MetaYamlWriter } from '../src/meta-yaml/meta-yaml-writer';
import { RecommendationsAnalyzer } from '../src/recommendations/recommendations-analyzer';
import { RecommendationsWriter } from '../src/recommendations/recommendations-writer';
import { VsixUrlAnalyzer } from '../src/extensions/vsix-url-analyzer';

/* eslint-disable @typescript-eslint/no-explicit-any */

jest.mock('fs-extra');

describe('Test Build', () => {
  let container: Container;

  const cheTheiaPluginsAnalyzerAnalyzeMock = jest.fn();
  const cheTheiaPluginsAnalyzer: any = {
    analyze: cheTheiaPluginsAnalyzerAnalyzeMock,
  };

  const chePluginsAnalyzerAnalyzeMock = jest.fn();
  const chePluginsAnalyzer: any = {
    analyze: chePluginsAnalyzerAnalyzeMock,
  };

  const cheEditorsAnalyzerAnalyzeMock = jest.fn();
  const cheEditorsAnalyzer: any = {
    analyze: cheEditorsAnalyzerAnalyzeMock,
  };

  const vsixUrlAnalyzerAnalyzeMock = jest.fn();
  const vsixUrlAnalyzer: any = {
    analyze: vsixUrlAnalyzerAnalyzeMock,
  };

  const featuredAnalyzerGenerateMock = jest.fn();
  const featuredAnalyzer: any = {
    generate: featuredAnalyzerGenerateMock,
  };

  const featuredWriterWriteReportMock = jest.fn();
  const featuredWriter: any = {
    writeReport: featuredWriterWriteReportMock,
  };

  const metaYamlWriterWriteMock = jest.fn();
  const metaYamlWriter: any = {
    write: metaYamlWriterWriteMock,
  };

  const externalImagesWriterWriteMock = jest.fn();
  const externalImagesWriter: any = {
    write: externalImagesWriterWriteMock,
  };

  const indexWriterWriteMock = jest.fn();
  const indexWriter: any = {
    write: indexWriterWriteMock,
  };

  const digestImagesHelperUpdateImagesMock = jest.fn();
  const digestImagesHelper: any = {
    updateImages: digestImagesHelperUpdateImagesMock,
  };

  const recommendationsAnalyzerGenerateMock = jest.fn();
  const recommendationsAnalyzer: any = {
    generate: recommendationsAnalyzerGenerateMock,
  };

  const recommendationsWriterWriteRecommendationsMock = jest.fn();
  const recommendationsWriter: any = {
    writeRecommendations: recommendationsWriterWriteRecommendationsMock,
  };

  const metaYamlGeneratorComputeMock = jest.fn();
  const cheTheiaPluginsMetaYamlGenerator: any = {
    compute: metaYamlGeneratorComputeMock,
  };

  const metaYamlPluginsGeneratorComputeMock = jest.fn();
  const chePluginsMetaYamlGenerator: any = {
    compute: metaYamlPluginsGeneratorComputeMock,
  };

  const metaYamlEditorGeneratorComputeMock = jest.fn();
  const cheEditorMetaYamlGenerator: any = {
    compute: metaYamlEditorGeneratorComputeMock,
  };

  const cheTheiaPluginsYamlWriterWriteMock = jest.fn();
  const cheTheiaPluginsYamlWriter: any = {
    write: cheTheiaPluginsYamlWriterWriteMock,
  };

  const cheTheiaPluginsYamlGeneratorComputeMock = jest.fn();
  const cheTheiaPluginsYamlGenerator: any = {
    compute: cheTheiaPluginsYamlGeneratorComputeMock,
  };

  let build: Build;

  async function buildCheMetaPluginYaml(): Promise<CheTheiaPluginYaml> {
    return {
      featured: false,
      sidecar: { image: 'fake-image' },
      repository: {
        url: 'http://fake-repository',
        revision: 'main',
      },
      extension: 'https://my-fake.vsix',
    };
  }

  async function buildChePluginYaml(): Promise<ChePluginYaml> {
    return {
      id: 'che-incubator/theia-dev/0.0.1',
      icon: '',
      displayName: 'Che Theia Dev Plugin',
      description: 'Che Theia Dev Plugin',
      repository: 'https://github.com/che-incubator/che-theia-dev-plugin/',
      firstPublicationDate: '2019-02-05',
      endpoints: [
        {
          name: 'theia-dev-flow',
          public: true,
          targetPort: 3010,
          attributes: {
            protocol: 'http',
          },
        },
      ],
      containers: [
        {
          name: 'theia-dev',
          image: 'quay.io/eclipse/che-theia-dev:next',
          mountSources: true,
          memoryLimit: '2Gi',
        },
      ],
    };
  }

  async function buildCheEditorYaml(): Promise<CheEditorYaml> {
    return {
      schemaVersion: '2.1.0',
      metadata: {
        name: 'ws-skeleton/eclipseide/4.9.0',
        displayName: 'Eclipse IDE',
        description: 'Eclipse running on the Web with Broadway',
        icon: 'https://cdn.freebiesupply.com/logos/large/2x/eclipse-11-logo-svg-vector.svg',
        attributes: {
          title: 'Eclipse IDE (in browser using Broadway) as editor for Eclipse Che',
          repository: 'https://github.com/ws-skeleton/che-editor-eclipseide/',
          firstPublicationDate: '2019-02-05',
        },
      },
      components: [
        {
          name: 'eclipse-ide',
          container: {
            image: 'docker.io/wsskeleton/eclipse-broadway',
            mountSources: true,
            memoryLimit: '2048M',
            endpoints: [
              {
                name: 'eclipse-ide',
                public: true,
                targetPort: 5000,
                attributes: {
                  protocol: 'http',
                  type: 'ide',
                },
              },
            ],
          },
        },
      ],
    };
  }

  beforeEach(() => {
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind('string').toConstantValue('/fake-root-directory').whenTargetNamed('PLUGIN_REGISTRY_ROOT_DIRECTORY');
    container.bind('string').toConstantValue('/fake-root-directory/output').whenTargetNamed('OUTPUT_ROOT_DIRECTORY');
    container.bind('boolean').toConstantValue(false).whenTargetNamed('SKIP_DIGEST_GENERATION');
    container.bind('string[]').toConstantValue([]).whenTargetNamed('ARGUMENTS');
    container.bind(FeaturedAnalyzer).toConstantValue(featuredAnalyzer);
    container.bind(FeaturedWriter).toConstantValue(featuredWriter);
    container.bind(RecommendationsAnalyzer).toConstantValue(recommendationsAnalyzer);
    container.bind(RecommendationsWriter).toConstantValue(recommendationsWriter);
    container.bind(VsixUrlAnalyzer).toConstantValue(vsixUrlAnalyzer);

    container.bind(CheTheiaPluginsAnalyzer).toConstantValue(cheTheiaPluginsAnalyzer);
    container.bind(CheTheiaPluginsMetaYamlGenerator).toConstantValue(cheTheiaPluginsMetaYamlGenerator);
    container.bind(CheTheiaPluginsYamlWriter).toConstantValue(cheTheiaPluginsYamlWriter);
    container.bind(CheTheiaPluginsYamlGenerator).toConstantValue(cheTheiaPluginsYamlGenerator);
    container.bind(ChePluginsAnalyzer).toConstantValue(chePluginsAnalyzer);
    container.bind(ChePluginsMetaYamlGenerator).toConstantValue(chePluginsMetaYamlGenerator);
    container.bind(CheEditorsAnalyzer).toConstantValue(cheEditorsAnalyzer);
    container.bind(CheEditorsMetaYamlGenerator).toConstantValue(cheEditorMetaYamlGenerator);
    container.bind(MetaYamlWriter).toConstantValue(metaYamlWriter);
    container.bind(ExternalImagesWriter).toConstantValue(externalImagesWriter);
    container.bind(IndexWriter).toConstantValue(indexWriter);
    container.bind(DigestImagesHelper).toConstantValue(digestImagesHelper);

    container.bind(Build).toSelf().inSingletonScope();
    build = container.get(Build);
  });

  test('basics', async () => {
    const cheTheiaPluginYaml = await buildCheMetaPluginYaml();
    // no id, so it will be computed

    const packageJson: any = {
      publisher: 'foobar-Publisher',
      name: 'ACuStOmName',
    };

    vsixUrlAnalyzerAnalyzeMock.mockImplementation((vsixInfo: any) => {
      vsixInfo.packageJson = packageJson;
    });
    const cheTheiaPluginsYaml: CheTheiaPluginsYaml = {
      plugins: [cheTheiaPluginYaml],
    };
    cheTheiaPluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheTheiaPluginsYaml);

    const chePluginYaml = await buildChePluginYaml();
    const chePluginsYaml: ChePluginsYaml = {
      plugins: [chePluginYaml],
    };
    chePluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(chePluginsYaml);

    const cheEditorPluginYaml = await buildCheEditorYaml();
    const cheEditorsYaml: CheEditorsYaml = {
      editors: [cheEditorPluginYaml],
    };
    cheEditorsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheEditorsYaml);

    metaYamlGeneratorComputeMock.mockResolvedValueOnce([]);
    metaYamlEditorGeneratorComputeMock.mockResolvedValueOnce([]);
    metaYamlPluginsGeneratorComputeMock.mockResolvedValueOnce([]);

    await build.build();
    expect(chePluginsMetaYamlGenerator.compute).toBeCalled();
    expect(cheEditorMetaYamlGenerator.compute).toBeCalled();
    expect(cheTheiaPluginsMetaYamlGenerator.compute).toBeCalled();
    const computeCall = metaYamlGeneratorComputeMock.mock.calls[0];
    // computed id should be all lowercase
    expect(computeCall[0][0].id).toBe('foobar-publisher/acustomname');

    expect(recommendationsWriter.writeRecommendations).toBeCalled();
    expect(vsixUrlAnalyzer.analyze).toBeCalled();
    expect(featuredAnalyzer.generate).toBeCalled();
    expect(featuredWriter.writeReport).toBeCalled();
    expect(recommendationsAnalyzer.generate).toBeCalled();
    expect(recommendationsWriter.writeRecommendations).toBeCalled();
    expect(externalImagesWriter.write).toBeCalled();
    expect(metaYamlWriter.write).toBeCalled();
    expect(indexWriter.write).toBeCalled();
    expect(cheTheiaPluginsYamlWriter.write).toBeCalled();
    expect(cheTheiaPluginsYamlGenerator.compute).toBeCalled();
    expect(digestImagesHelper.updateImages).toBeCalled();
  });

  test('basics without package.json', async () => {
    const cheTheiaPluginYaml = await buildCheMetaPluginYaml();
    const cheTheiaPluginsYaml: CheTheiaPluginsYaml = {
      plugins: [cheTheiaPluginYaml],
    };

    cheTheiaPluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheTheiaPluginsYaml);

    await expect(build.build()).rejects.toThrow('Unable to find a package.json file for extension');
  });

  test('basics with no extensions', async () => {
    const cheTheiaPluginYaml = await buildCheMetaPluginYaml();
    delete (cheTheiaPluginYaml as any).extensions;
    const cheTheiaPluginsYaml: CheTheiaPluginsYaml = {
      plugins: [cheTheiaPluginYaml],
    };

    const chePluginsYaml: ChePluginsYaml = {
      plugins: [],
    };
    chePluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(chePluginsYaml);

    const cheEditorsYaml: CheEditorsYaml = {
      editors: [],
    };
    cheEditorsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheEditorsYaml);
    cheTheiaPluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheTheiaPluginsYaml);

    await expect(build.build()).rejects.toThrow('Unable to find a package.json file for extension');
  });

  test('basics with empty vsixInfos', async () => {
    const analyzeCheTheiaPluginSpy = jest.spyOn(build, 'analyzeCheTheiaPlugin');
    analyzeCheTheiaPluginSpy.mockImplementation(async (cheTheiaPlugin: CheTheiaPluginAnalyzerMetaInfo) =>
      cheTheiaPlugin.vsixInfos.clear()
    );

    const cheTheiaPluginYaml = await buildCheMetaPluginYaml();
    const cheTheiaPluginsYaml: CheTheiaPluginsYaml = {
      plugins: [cheTheiaPluginYaml],
    };

    const chePluginsYaml: ChePluginsYaml = {
      plugins: [],
    };
    chePluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(chePluginsYaml);

    const cheEditorsYaml: CheEditorsYaml = {
      editors: [],
    };
    cheEditorsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheEditorsYaml);

    cheTheiaPluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheTheiaPluginsYaml);

    await expect(build.build()).rejects.toThrow('Unable to find a package.json file for extension');
  });

  test('basics without publisher', async () => {
    const cheTheiaPluginYaml = await buildCheMetaPluginYaml();
    // no id, so it will be computed
    const packageJson: any = {
      name: 'ACuStOmName',
    };

    vsixUrlAnalyzerAnalyzeMock.mockImplementation((vsixInfo: any) => {
      vsixInfo.packageJson = packageJson;
    });
    const cheTheiaPluginsYaml: CheTheiaPluginsYaml = {
      plugins: [cheTheiaPluginYaml],
    };

    const chePluginsYaml: ChePluginsYaml = {
      plugins: [],
    };
    chePluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(chePluginsYaml);

    const cheEditorsYaml: CheEditorsYaml = {
      editors: [],
    };
    cheEditorsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheEditorsYaml);
    cheTheiaPluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheTheiaPluginsYaml);

    await expect(build.build()).rejects.toThrow('Unable to find a publisher field in package.json file for extension');
  });

  test('basics without name', async () => {
    const cheTheiaPluginYaml = await buildCheMetaPluginYaml();
    // no id, so it will be computed
    const packageJson: any = {
      publisher: 'ACuStOmName',
    };

    vsixUrlAnalyzerAnalyzeMock.mockImplementation((vsixInfo: any) => {
      vsixInfo.packageJson = packageJson;
    });
    const cheTheiaPluginsYaml: CheTheiaPluginsYaml = {
      plugins: [cheTheiaPluginYaml],
    };

    cheTheiaPluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheTheiaPluginsYaml);

    const chePluginsYaml: ChePluginsYaml = {
      plugins: [],
    };
    chePluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(chePluginsYaml);

    const cheEditorsYaml: CheEditorsYaml = {
      editors: [],
    };
    cheEditorsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheEditorsYaml);
    await expect(build.build()).rejects.toThrow('Unable to find a name field in package.json file for extension');
  });

  test('basics without extension', async () => {
    const cheTheiaPluginYaml = await buildCheMetaPluginYaml();
    delete (cheTheiaPluginYaml as any).extension;

    const cheTheiaPluginsYaml: CheTheiaPluginsYaml = {
      plugins: [cheTheiaPluginYaml],
    };

    cheTheiaPluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheTheiaPluginsYaml);

    const chePluginsYaml: ChePluginsYaml = {
      plugins: [],
    };
    chePluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(chePluginsYaml);

    const cheEditorsYaml: CheEditorsYaml = {
      editors: [],
    };
    cheEditorsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheEditorsYaml);
    await expect(build.build()).rejects.toThrow('does not have mandatory extension field');
  });

  test('basics with id', async () => {
    const cheTheiaPluginYaml = await buildCheMetaPluginYaml();
    cheTheiaPluginYaml.id = 'my/id';

    const cheTheiaPluginsYaml: CheTheiaPluginsYaml = {
      plugins: [cheTheiaPluginYaml],
    };

    cheTheiaPluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheTheiaPluginsYaml);

    const chePluginYaml = await buildChePluginYaml();
    const chePluginsYaml: ChePluginsYaml = {
      plugins: [chePluginYaml],
    };
    chePluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(chePluginsYaml);

    const cheEditorPluginYaml = await buildCheEditorYaml();
    const cheEditorsYaml: CheEditorsYaml = {
      editors: [cheEditorPluginYaml],
    };
    cheEditorsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheEditorsYaml);

    metaYamlGeneratorComputeMock.mockResolvedValueOnce([]);
    metaYamlEditorGeneratorComputeMock.mockResolvedValueOnce([]);
    metaYamlPluginsGeneratorComputeMock.mockResolvedValueOnce([]);
    await build.build();
    expect(cheTheiaPluginsMetaYamlGenerator.compute).toBeCalled();
    const computeCall = metaYamlGeneratorComputeMock.mock.calls[0];
    expect(computeCall[0][0].id).toBe('my/id');

    expect(recommendationsWriter.writeRecommendations).toBeCalled();
    expect(vsixUrlAnalyzer.analyze).toBeCalled();
    expect(featuredAnalyzer.generate).toBeCalled();
    expect(featuredWriter.writeReport).toBeCalled();
    expect(recommendationsAnalyzer.generate).toBeCalled();
    expect(recommendationsWriter.writeRecommendations).toBeCalled();
    expect(externalImagesWriter.write).toBeCalled();
    expect(metaYamlWriter.write).toBeCalled();
    expect(indexWriter.write).toBeCalled();
  });

  test('succed task', async () => {
    const deferred = new Deferred();
    let currentValue = false;
    const task = ora('my-task').start();
    build.updateTask(deferred.promise, task, () => (currentValue = true), 'error');
    expect(currentValue).toBeFalsy();
    deferred.resolve();
    await deferred.promise;
    expect(currentValue).toBeTruthy();
  });

  test('with a fail task', async () => {
    const deferred = new Deferred();
    let currentValue = false;
    const task = ora('my-task').start();
    const spyTask = jest.spyOn(task, 'fail');
    build.updateTask(deferred.promise, task, () => (currentValue = true), 'error');
    expect(currentValue).toBeFalsy();
    deferred.reject('rejecting');
    await expect(deferred.promise).rejects.toMatch('rejecting');
    expect(currentValue).toBeFalsy();
    expect(spyTask).toBeCalled();
    expect(spyTask.mock.calls[0][0]).toBe('error');
  });

  test('with a fail wrapIntoTask', async () => {
    const deferred = new Deferred();
    const task = ora('my-task').start();
    const spyFailTask = jest.spyOn(task, 'fail');
    build.wrapIntoTask('This is my task', deferred.promise, task);
    deferred.reject('rejecting');
    await expect(deferred.promise).rejects.toMatch('rejecting');
    expect(spyFailTask).toBeCalled();
    expect(spyFailTask.mock.calls[0][0]).toBeUndefined();
  });

  test('basics with skip Digests', async () => {
    container.rebind('boolean').toConstantValue(true).whenTargetNamed('SKIP_DIGEST_GENERATION');
    // force to refresh the singleton
    container.rebind(Build).toSelf().inSingletonScope();
    build = container.get(Build);
    const cheTheiaPluginYaml = await buildCheMetaPluginYaml();
    // no id, so it will be computed

    const packageJson: any = {
      publisher: 'foobar-Publisher',
      name: 'ACuStOmName',
    };

    vsixUrlAnalyzerAnalyzeMock.mockImplementation((vsixInfo: any) => {
      vsixInfo.packageJson = packageJson;
    });
    const cheTheiaPluginsYaml: CheTheiaPluginsYaml = {
      plugins: [cheTheiaPluginYaml],
    };
    cheTheiaPluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheTheiaPluginsYaml);

    const chePluginYaml = await buildChePluginYaml();
    const chePluginsYaml: ChePluginsYaml = {
      plugins: [chePluginYaml],
    };
    chePluginsAnalyzerAnalyzeMock.mockResolvedValueOnce(chePluginsYaml);

    const cheEditorPluginYaml = await buildCheEditorYaml();
    const cheEditorsYaml: CheEditorsYaml = {
      editors: [cheEditorPluginYaml],
    };
    cheEditorsAnalyzerAnalyzeMock.mockResolvedValueOnce(cheEditorsYaml);

    metaYamlGeneratorComputeMock.mockResolvedValueOnce([]);
    metaYamlEditorGeneratorComputeMock.mockResolvedValueOnce([]);
    metaYamlPluginsGeneratorComputeMock.mockResolvedValueOnce([]);

    await build.build();
    //  check that we don't call digest update
    expect(digestImagesHelper.updateImages).toBeCalledTimes(0);
  });
});
