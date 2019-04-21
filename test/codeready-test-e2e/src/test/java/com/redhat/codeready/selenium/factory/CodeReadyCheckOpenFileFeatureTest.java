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
package com.redhat.codeready.selenium.factory;

import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.WIDGET_TIMEOUT_SEC;

import org.eclipse.che.selenium.factory.CheckOpenFileFeatureTest;

/** @author Aleksandr Shmaraiev */
public class CodeReadyCheckOpenFileFeatureTest extends CheckOpenFileFeatureTest {

  @Override
  protected void selectSample() {
    String sampleName = "kitchensink-example";
    wizard.selectSample(sampleName);
  }

  @Override
  protected void waitTabIsPresent() {
    editor.waitTabIsPresent("jboss-as-kitchensink", WIDGET_TIMEOUT_SEC);
  }
}
