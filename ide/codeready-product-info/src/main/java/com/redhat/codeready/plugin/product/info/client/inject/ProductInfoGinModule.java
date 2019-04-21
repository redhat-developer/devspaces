/*
 * Copyright (c) 2019 Red Hat, Inc.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v2.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *   Red Hat, Inc. - initial API and implementation
 */
package com.redhat.codeready.plugin.product.info.client.inject;

import com.google.gwt.inject.client.AbstractGinModule;
import com.redhat.codeready.plugin.product.info.client.CodeReadyProductInfoDataProvider;
import org.eclipse.che.ide.api.ProductInfoDataProviderImpl;
import org.eclipse.che.ide.api.extension.ExtensionGinModule;

@ExtensionGinModule
public class ProductInfoGinModule extends AbstractGinModule {
  /** {@inheritDoc} */
  @Override
  protected void configure() {
    bind(ProductInfoDataProviderImpl.class).to(CodeReadyProductInfoDataProvider.class);
  }
}
