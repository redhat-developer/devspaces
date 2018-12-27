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
package com.redhat.codeready.selenium.debugger;

import org.eclipse.che.selenium.debugger.CppProjectDebuggingTest;

/**
 * @author Dmytro Nochevnov
 * @author Aleksandr Shmaraiev
 */
public class CodeReadyCppProjectDebuggingTest extends CppProjectDebuggingTest {

  @Override
  protected void waitTextInVariablesPanel() {
    debugPanel.waitTextInVariablesPanel("name=");
  }
}
