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

import static org.eclipse.che.selenium.core.constant.TestBuildConstants.BUILD_SUCCESS;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.EXPECTED_MESS_IN_CONSOLE_SEC;

import org.eclipse.che.selenium.intelligencecommand.CommandsPaletteTest;
import org.eclipse.che.selenium.pageobject.intelligent.CommandsPalette;
import org.testng.annotations.Test;

/**
 * @author Aleksandr Shmaraev
 *     <p>Note: test are being overrided in class to support proper sequence of tests (issue
 *     CRW-155).
 */
public class CodeReadyCommandsPaletteTest extends CommandsPaletteTest {

  @Override
  protected void selectSampleProject() {
    String sampleProjectName = "kitchensink-example";
    wizard.selectProjectAndCreate(sampleProjectName, PROJECT_NAME);
  }

  @Override
  protected void startCommandByDoubleClick() {
    commandsPalette.startCommandByDoubleClick(PROJECT_NAME + ": build and run in debug");
    consoles.waitExpectedTextIntoConsole("started in", EXPECTED_MESS_IN_CONSOLE_SEC);
  }

  @Override
  protected void startCommandFromSearchList() {
    commandsPalette.searchAndStartCommand("hot update");
    commandsPalette.startCommandByDoubleClick(PROJECT_NAME + ": hot update");
    consoles.waitTabNameProcessIsPresent(PROJECT_NAME + ": hot update");
  }

  @Override
  protected void selectCommandByKeyboardNavigation() {
    commandsPalette.moveAndStartCommand(CommandsPalette.MoveTypes.DOWN, 2);
    consoles.waitTabNameProcessIsPresent(PROJECT_NAME + ": build");
    consoles.waitExpectedTextIntoConsole(BUILD_SUCCESS, EXPECTED_MESS_IN_CONSOLE_SEC);
  }

  @Test
  @Override
  public void commandPaletteTest() {
    super.commandPaletteTest();
  }

  @Test(priority = 1)
  @Override
  public void newCommandTest() {
    super.newCommandTest();
  }
}
