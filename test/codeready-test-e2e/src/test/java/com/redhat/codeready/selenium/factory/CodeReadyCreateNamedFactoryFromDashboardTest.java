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

import org.eclipse.che.selenium.factory.CreateNamedFactoryFromDashboardTest;

/** @author Aleksandr Shmaraiev */
public class CodeReadyCreateNamedFactoryFromDashboardTest
    extends CreateNamedFactoryFromDashboardTest {

  @Override
  protected void selectSampleProject() {
    String sampleProjectName = "kitchensink-example";
    wizard.selectProjectAndCreate(sampleProjectName, PROJECT_NAME);
  }
}
