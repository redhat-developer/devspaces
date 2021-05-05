/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
import { ContainerModule, interfaces } from 'inversify';

import { VsixDownload } from './vsix-download';
import { VsixReadInfo } from './vsix-read-info';
import { VsixUnpack } from './vsix-unpack';
import { VsixUrlAnalyzer } from './vsix-url-analyzer';

const extensionsModule = new ContainerModule((bind: interfaces.Bind) => {
  bind(VsixDownload).toSelf().inSingletonScope();
  bind(VsixReadInfo).toSelf().inSingletonScope();
  bind(VsixUnpack).toSelf().inSingletonScope();
  bind(VsixUrlAnalyzer).toSelf().inSingletonScope();
});

export { extensionsModule };
