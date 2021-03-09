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

import { Container } from 'inversify';
import { FeaturedWriter } from '../../src/featured/featured-writer';

describe('Test Featured', () => {
  let container: Container;

  let featuredWriter: FeaturedWriter;

  beforeEach(() => {
    jest.restoreAllMocks();
    jest.resetAllMocks();
    container = new Container();
    container.bind(FeaturedWriter).toSelf().inSingletonScope();
    container.bind('string').toConstantValue('/fake-output').whenTargetNamed('OUTPUT_ROOT_DIRECTORY');

    featuredWriter = container.get(FeaturedWriter);
  });

  test('basics', async () => {
    const ensureDirSpy = jest.spyOn(fs, 'ensureDir');
    ensureDirSpy.mockReturnValue();
    const featuredJson: any = { hello: 'foo' };
    const writeFileSpy = jest.spyOn(fs, 'writeFile');
    writeFileSpy.mockReturnValue();

    await featuredWriter.writeReport(featuredJson);

    expect(writeFileSpy).toBeCalled();
    // check we ensure parent folder exists
    expect(ensureDirSpy).toBeCalled();

    const callWrite = writeFileSpy.mock.calls[0];
    // write path is ok
    expect(callWrite[0]).toBe('/fake-output/v3/che-theia/featured.json');

    // should be indented with 2 spaces
    expect(callWrite[1]).toBe('{\n  "hello": "foo"\n}\n');
  });
});
