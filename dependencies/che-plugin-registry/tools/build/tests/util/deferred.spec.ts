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

import { Deferred } from '../../src/util/deferred';

describe('Test Deferred', () => {
  test('defer', async () => {
    const deferred = new Deferred();
    const promise = deferred.promise;
    let isResolved = false;
    promise.then(() => {
      isResolved = true;
    });
    expect(isResolved).toBeFalsy();
    deferred.resolve(true);
    const result = await promise;
    expect(isResolved).toBeTruthy();
    expect(result).toBeTruthy();
  });
});
