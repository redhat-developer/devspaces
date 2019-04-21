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
package com.redhat.codeready.plugin.product.info.client;

import com.google.gwt.resources.client.ClientBundle;
import org.vectomatic.dom.svg.ui.SVGResource;

/** Hosted extension resources. */
public interface CodeReadyResources extends ClientBundle {
  @Source("logo/CRW_logo-buildinfo-white.svg")
  SVGResource logoWhite();

  @Source("logo/CRW_logo-buildinfo-black.svg")
  SVGResource logoBlack();

  @Source("logo/CodeReady_icon.svg")
  SVGResource waterMarkLogo();
}
