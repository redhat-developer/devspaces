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

import { Container } from 'inversify';
import { DevImagesHelper } from '../../src/meta-yaml/dev-images-helper';
import { MetaYamlPluginInfo } from '../../src/meta-yaml/meta-yaml-plugin-info';

describe('Test DevImagesHelper', () => {
  let container: Container;

  let metaYamlPlugins: MetaYamlPluginInfo[];
  let devImagesHelper: DevImagesHelper;

  beforeEach(() => {
    metaYamlPlugins = [
      {
        spec: {
          containers: [{ image: 'registry.redhat.io/codeready-workspaces/container-image1:foo' }, { image: 'quay.io/crw/container-image2:bar' }],
          initContainers: [{ image: 'init-container-image1:foo' }, { image: 'registry.redhat.io/codeready-workspaces/init-container-image2:bar' }],
        },
      } as any,
      {
        spec: {
          containers: [{ image: 'registry.redhat.io/openshift/container-image1:foo' }, { image: 'quay.io/codeready-workspaces/container-image2:bar' }],
          initContainers: [{ image: 'registry.redhat.io/codeready-workspaces/init-container-image1:foo' }, { image: 'registry.redhat.io/openshift/init-container-image2:bar' }],
        },
      } as any,
    ];

    container = new Container();

    container.bind(DevImagesHelper).toSelf().inSingletonScope();
    devImagesHelper = container.get(DevImagesHelper);
  });

  test('basics', async () => {


    const updatedYamls = await devImagesHelper.replaceImagePrefix(metaYamlPlugins, 'registry.redhat.io/codeready-workspaces', 'quay.io/crw');
    const firstYaml = updatedYamls[0];
    expect((firstYaml.spec.containers as any)[0].image).toBe('quay.io/crw/container-image1:foo');
    expect((firstYaml.spec.containers as any)[1].image).toBe('quay.io/crw/container-image2:bar');
    expect((firstYaml.spec.initContainers as any)[0].image).toBe('init-container-image1:foo');
    expect((firstYaml.spec.initContainers as any)[1].image).toBe('quay.io/crw/init-container-image2:bar');
    const secondYaml = updatedYamls[1];
    expect((secondYaml.spec.containers as any)[0].image).toBe('registry.redhat.io/openshift/container-image1:foo');
    expect((secondYaml.spec.containers as any)[1].image).toBe('quay.io/codeready-workspaces/container-image2:bar');
    expect((secondYaml.spec.initContainers as any)[0].image).toBe('quay.io/crw/init-container-image1:foo');
    expect((secondYaml.spec.initContainers as any)[1].image).toBe('registry.redhat.io/openshift/init-container-image2:bar');
  });
});
