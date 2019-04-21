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
package com.redhat.codeready.selenium.projectexplorer;

import org.eclipse.che.selenium.projectexplorer.CheckShowHideHiddenFilesTest;

public class CodeReadyCheckShowHideHiddenFilesTest extends CheckShowHideHiddenFilesTest {

  @Override
  protected void selectSampleProject() {
    projectWizard.selectSample("kitchensink-example");
  }
}
