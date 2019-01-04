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

/** @author Aleksandr Shmaraev */
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
}
