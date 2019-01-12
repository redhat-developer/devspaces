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
package com.redhat.codeready.selenium.workspaces;

import org.eclipse.che.selenium.workspaces.CreateWorkspaceOnDashboardTest;

public class CodeReadyCreateWorkspaceOnDashboardTest extends CreateWorkspaceOnDashboardTest {

  @Override
  protected void selectSampleProject() {
    String sampleProjectName = "kitchensink-example";
    wizard.selectProjectAndCreate(sampleProjectName, PROJECT_NAME);
  }

  @Override
  protected void expandPathInProjectExplorer() {
    String pathToExpand = "/src/main/java/org.jboss.as.quickstarts.kitchensink/controller";
    projectExplorer.expandPathInProjectExplorer(PROJECT_NAME + pathToExpand);
  }

  @Override
  protected void openItemByPath() {
    String pathToMainPackage =
        "/src/main/java/org/jboss/as/quickstarts/kitchensink/controller/MemberRegistration.java";
    projectExplorer.openItemByPath(PROJECT_NAME + pathToMainPackage);
  }

  @Override
  protected void waitTabIsPresent() {
    editor.waitTabIsPresent("MemberRegistration");
  }
}
