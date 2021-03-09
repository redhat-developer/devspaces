/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
import { VsixInfo } from '../../src/extensions/vsix-info';

export function createVsixInfo(): VsixInfo {
  const extensions: string[] = [];
  const vsixInfos = new Map<string, VsixInfo>();
  const id = 'my-id';
  const featured = true;
  const sidecar = {
    image: 'foo',
  };
  const repository = {
    url: 'http://foo-repository',
    revision: 'main',
  };
  const aliases: string[] = [];

  const cheTheiaPlugin = { id, extensions, aliases, repository, sidecar, featured, vsixInfos };
  const vsixInfoToAnalyze: VsixInfo = {
    uri: 'my-fake.vsix',
    cheTheiaPlugin,
  };
  return vsixInfoToAnalyze;
}
