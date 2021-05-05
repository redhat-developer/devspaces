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

import { FeaturedAnalyzer } from './featured-analyzer';
import { FeaturedWriter } from './featured-writer';

const featuredModule = new ContainerModule((bind: interfaces.Bind) => {
  bind(FeaturedAnalyzer).toSelf().inSingletonScope();
  bind(FeaturedWriter).toSelf().inSingletonScope();
});

export { featuredModule };
