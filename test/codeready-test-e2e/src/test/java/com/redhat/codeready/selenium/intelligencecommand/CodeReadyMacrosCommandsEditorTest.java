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
package com.redhat.codeready.selenium.intelligencecommand;

import org.eclipse.che.selenium.intelligencecommand.MacrosCommandsEditorTest;
import org.testng.annotations.Test;

/**
 * @author Aleksandr Shmaraev
 *     <p>Note: test are being overrided in class to support proper sequence of tests (issue
 *     CRW-155).
 */
public class CodeReadyMacrosCommandsEditorTest extends MacrosCommandsEditorTest {

  @Override
  protected String[] getArraytMacrosItems() {
    String[] macrosItems = {
      "${server.eap-debug}",
      "${server.eap}",
      "${server.exec-agent/http}",
      "${server.exec-agent/ws}",
      "${server.terminal}",
      "${server.wsagent/http}",
      "${server.wsagent/ws}"
    };
    return macrosItems;
  }

  @Test(priority = 1)
  @Override
  public void checkCommandMacrosIntoCommandLine() {
    super.checkCommandMacrosIntoCommandLine();
  }

  @Test(priority = 2)
  @Override
  public void checkCommandMacrosIntoPreviewUrl() {
    super.checkCommandMacrosIntoPreviewUrl();
  }
}
