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
package com.redhat.codeready.selenium.languageserver;

import org.eclipse.che.selenium.languageserver.GolangFileEditingTest;

/** @author Aleksandr Shmaraev */
public class CodeReadyGolangFileEditingTest extends GolangFileEditingTest {

  @Override
  protected void waitExpectedTextIntoConsole() {
    consoles.waitExpectedTextIntoConsole("Finished running tool:");
    consoles.waitExpectedTextIntoConsole("/usr/bin/go build");
  }
}
