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
  protected String getSampleProjectName() {
    return "kitchensink-example";
  }

  @Override
  protected String getPathToExpand() {
    return "/src/main/java/org.jboss.as.quickstarts.kitchensink/controller";
  }

  @Override
  protected String getPathJavaFile() {
    return "/src/main/java/org/jboss/as/quickstarts/kitchensink/controller/MemberRegistration.java";
  }

  @Override
  protected String getTabName() {
    return "MemberRegistration";
  }
}
