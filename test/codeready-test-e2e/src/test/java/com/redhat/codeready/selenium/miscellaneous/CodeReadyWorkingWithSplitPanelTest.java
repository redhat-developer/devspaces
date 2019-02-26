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

import org.eclipse.che.selenium.miscellaneous.WorkingWithSplitPanelTest;
import org.testng.annotations.Test;

/**
 * @author Aleksandr Shmaraev
 *     <p>Note: test are being overrided in class to support proper sequence of tests (issue
 *     CRW-155).
 */
public class CodeReadyWorkingWithSplitPanelTest extends WorkingWithSplitPanelTest {

  @Override
  protected String getCommandToCheckTerminal() {
    return "pwd";
  }

  @Override
  protected void checkExpectedTextIsPresent() {}

  @Test
  @Override
  public void checkMultiSplitPane() {
    super.checkMultiSplitPane();
  }

  @Test(priority = 1)
  @Override
  public void checkTerminalAndBuild() {
    super.checkTerminalAndBuild();
  }

  @Test(priority = 2)
  @Override
  public void checkTabsOnSplitPanel() {
    super.checkTabsOnSplitPanel();
  }

  @Test(priority = 3)
  @Override
  public void checkSwitchingTabsAndPanels() {
    super.checkSwitchingTabsAndPanels();
  }
}
