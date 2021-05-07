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
/* eslint-disable @typescript-eslint/no-non-null-assertion */
import 'reflect-metadata';

import { CommonEndpointYaml } from '../../src/common/common-endpoint-yaml';
import { Container } from 'inversify';
import { EndpointsHelper } from '../../src/common/endpoints-helper';

describe('Test EndpointsHelper', () => {
  let endpointsHelper: EndpointsHelper;
  let container: Container;

  beforeEach(() => {
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind('string').toConstantValue('/fake-output').whenTargetNamed('OUTPUT_ROOT_DIRECTORY');

    container.bind(EndpointsHelper).toSelf().inSingletonScope();
    endpointsHelper = container.get(EndpointsHelper);
  });

  test('basics', async () => {
    const endpointYaml: CommonEndpointYaml = {
      name: 'endpoint-name',
      path: 'endpoint-path',
      exposure: 'public',
      protocol: 'http',
      secure: true,
    };
    const volumes = new Map();
    volumes.set('example', { ephemeral: true });
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const endpoint: any = await endpointsHelper.resolve(endpointYaml);
    expect(endpoint).toBeDefined();
    expect(endpoint.public).toBeTruthy();
    expect(endpoint.attributes.protocol).toBe('http');
    expect(endpoint.attributes.secure).toBeTruthy();
    expect(endpoint.exposure).toBeUndefined();
    expect(endpoint.secure).toBeUndefined();
  });
});
