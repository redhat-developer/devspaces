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

import { RecommendationsAnalyzer } from './recommendations-analyzer';
import { RecommendationsWriter } from './recommendations-writer';

const recommendationsModule = new ContainerModule((bind: interfaces.Bind) => {
  bind(RecommendationsAnalyzer).toSelf().inSingletonScope();
  bind(RecommendationsWriter).toSelf().inSingletonScope();
});

export { recommendationsModule };
