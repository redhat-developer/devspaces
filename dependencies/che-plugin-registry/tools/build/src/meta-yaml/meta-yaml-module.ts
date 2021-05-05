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

import { DigestImagesHelper } from './digest-images-helper';
import { ExternalImagesWriter } from './external-images-writer';
import { IndexWriter } from './index-writer';
import { MetaYamlWriter } from './meta-yaml-writer';

const metaYamlModule = new ContainerModule((bind: interfaces.Bind) => {
  bind(DigestImagesHelper).toSelf().inSingletonScope();
  bind(ExternalImagesWriter).toSelf().inSingletonScope();
  bind(IndexWriter).toSelf().inSingletonScope();
  bind(MetaYamlWriter).toSelf().inSingletonScope();
});

export { metaYamlModule };
