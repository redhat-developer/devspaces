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

import org.eclipse.che.selenium.miscellaneous.OpenInTerminalTest;

/** @author Aleksandr Shmaraev */
public class CodeReadyOpenInTerminalTest extends OpenInTerminalTest {

  @Override
  protected void waitTextInTerminal() throws Exception {
    terminal.waitTextInTerminal(2, "[jboss@" + workspace.getId() + " java]$");
  }
}
