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
package com.redhat.codeready.selenium.factory;

import org.eclipse.che.selenium.factory.CheckRunCommandFeatureTest;

/** @author Aleksandr Shmaraiev */
public class CodeReadyCheckRunCommandFeatureTest extends CheckRunCommandFeatureTest {

  @Override
  protected void selectSample() {
    String sampleName = "kitchensink-example";
    wizard.selectSample(sampleName);
  }

  @Override
  protected void enterParamValueOnDashboardFactories() {
    String nameBuildCommand = PROJECT_NAME + ": build";
    dashboardFactories.enterParamValue(nameBuildCommand);
  }
}
