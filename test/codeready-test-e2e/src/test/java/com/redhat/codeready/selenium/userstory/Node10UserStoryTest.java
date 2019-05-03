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
package com.redhat.codeready.selenium.userstory;

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.NODE10;

import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import java.io.IOException;
import java.net.URISyntaxException;

public class Node10UserStoryTest extends Node8UserStoryTest {
  public Node10UserStoryTest() throws IOException, URISyntaxException {
    super();
  }

  @Override
  protected CodereadyNewWorkspace.CodereadyStacks getStackName() {
    return NODE10;
  }
}
