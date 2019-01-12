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
package com.redhat.codeready.selenium.miscellaneous;

import org.eclipse.che.selenium.miscellaneous.ResolveDependencyAfterRecreateProjectTest;

/** @author Aleksandr Shmaraev */
public class CodeReadyResolveDependencyAfterRecreateProjectTest
    extends ResolveDependencyAfterRecreateProjectTest {

  @Override
  protected void selectSampleProject() {
    String sampleProjectName = "kitchensink-example";
    wizard.selectSample(sampleProjectName);
  }

  @Override
  protected void expandPathInProjectExplorer(String projectName) {
    String pathToExpand = "/src/main/java/org.jboss.as.quickstarts.kitchensink/controller";
    projectExplorer.expandPathInProjectExplorer(projectName + pathToExpand);
  }

  @Override
  protected void openItemByPath(String projectName) {
    String pathToFile =
        "/src/main/java/org/jboss/as/quickstarts/kitchensink/controller/MemberRegistration.java";
    projectExplorer.openItemByPath(projectName + pathToFile);
  }
}
