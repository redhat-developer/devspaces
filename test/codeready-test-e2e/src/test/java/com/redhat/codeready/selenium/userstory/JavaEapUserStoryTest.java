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
package com.redhat.codeready.selenium.userstory;

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.JAVA_EAP;

import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;

/** @author Musienko Maxim */
public class JavaEapUserStoryTest extends JavaUserStoryTest {

  @Override
  protected CodereadyNewWorkspace.CodereadyStacks getStackName() {
    return JAVA_EAP;
  }
}
