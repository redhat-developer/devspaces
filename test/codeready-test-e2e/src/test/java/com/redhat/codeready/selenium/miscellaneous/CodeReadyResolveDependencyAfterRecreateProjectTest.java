/*
* Copyright (c) 2019 Red Hat, Inc.

* All rights reserved. This program and the accompanying materials
* are made available under the terms of the Eclipse Public License v2.0
* which accompanies this distribution, and is available at
* http://www.eclipse.org/legal/epl-2.0
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
  protected String getSampleProjectName() {
    return "kitchensink-example";
  }

  @Override
  protected String getPathToExpand() {
    return "/src/main/java/org.jboss.as.quickstarts.kitchensinkjsp/controller";
  }

  @Override
  protected String getPathToFile() {
    return "/src/main/java/org/jboss/as/quickstarts/kitchensinkjsp/controller/MemberRegistration.java";
  }
}
