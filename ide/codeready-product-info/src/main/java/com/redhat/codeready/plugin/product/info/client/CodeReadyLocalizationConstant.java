/*
* Copyright (c) 2018 Red Hat, Inc.

* All rights reserved. This program and the accompanying materials
* are made available under the terms of the Eclipse Public License v1.0
* which accompanies this distribution, and is available at
* http://www.eclipse.org/legal/epl-v10.html
*
* Contributors:
*   Red Hat, Inc. - initial API and implementation
*/
package com.redhat.codeready.plugin.product.info.client;

import com.google.gwt.i18n.client.Messages;

/** CodeReady product information constant. */
public interface CodeReadyLocalizationConstant extends Messages {

  @Key("codeready.tab.title")
  String codeReadyTabTitle();

  @Key("codeready.tab.title.with.workspace.name")
  String codeReadyTabTitle(String workspaceName);

  @Key("get.support.link")
  String getSupportLink();

  @Key("get.product.name")
  String getProductName();

  @Key("support.title")
  String supportTitle();
}
