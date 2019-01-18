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

import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Workspace.CREATE_PROJECT;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Workspace.WORKSPACE;
import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertFalse;

import org.eclipse.che.selenium.miscellaneous.FindTextFeatureTest;
import org.eclipse.che.selenium.pageobject.FindText.SearchFileResult;
import org.testng.annotations.Test;

/** @author Aleksandr Shmaraev */
public class CodeReadyFindTextFeatureTest extends FindTextFeatureTest {

  @Override
  @Test
  public void checkTextResultsPagination() {
    SearchFileResult searchFileResult;

    // Import the kitchensink-example project and find all occurrences of 'import'
    menu.runCommand(WORKSPACE, CREATE_PROJECT);
    wizard.selectProjectAndCreate("kitchensink-example", "kitchensink-example");
    notificationsPopupPanel.waitProgressPopupPanelClose();
    projectExplorer.waitItem("kitchensink-example");
    projectExplorer.waitAndSelectItem("kitchensink-example");

    findTextPage.launchFindFormByKeyboard();
    findTextPage.waitFindTextMainFormIsOpen();
    findTextPage.typeTextIntoFindField("import");
    findTextPage.waitTextIntoFindField("import");
    findTextPage.clickOnSearchButtonMainForm();
    findTextPage.waitFindInfoPanelIsOpen();

    // Check move page buttons status
    assertFalse(findTextPage.checkNextPageButtonIsEnabled());
    assertFalse(findTextPage.checkPreviousPageButtonIsEnabled());
    searchFileResult = findTextPage.getResults();
    assertEquals(searchFileResult.getFoundFilesOnPage(), 8);
    assertEquals(searchFileResult.getFoundOccurrencesOnPage(), 79);
  }
}
