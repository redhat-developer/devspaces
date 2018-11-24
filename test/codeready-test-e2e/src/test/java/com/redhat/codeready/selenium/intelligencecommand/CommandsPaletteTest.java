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
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandsGoals.COMMON_GOAL;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandsTypes.CUSTOM_TYPE;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.EXPECTED_MESS_IN_CONSOLE_SEC;

import com.google.inject.Inject;
import org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Workspace;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.pageobject.AskDialog;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.Loader;
import org.eclipse.che.selenium.pageobject.Menu;
import org.eclipse.che.selenium.pageobject.NotificationsPopupPanel;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.Wizard;
import org.eclipse.che.selenium.pageobject.intelligent.CommandsEditor;
import org.eclipse.che.selenium.pageobject.intelligent.CommandsExplorer;
import org.eclipse.che.selenium.pageobject.intelligent.CommandsPalette;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/** @author Sergey Skorik */
public class CommandsPaletteTest {
  private static final String PROJECT_NAME = "project";
  private static final String COMMAND = PROJECT_NAME + ": build";
  private static final String customCommandName = "newCustom";

  @Inject private TestWorkspace testWorkspace;
  @Inject private CommandsPalette commandsPalette;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private Consoles consoles;
  @Inject private Menu menu;
  @Inject private CommandsEditor commandsEditor;
  @Inject private CommandsExplorer commandsExplorer;
  @Inject private Loader loader;
  @Inject private AskDialog askDialog;
  @Inject private Ide ide;
  @Inject private NotificationsPopupPanel notificationsPopupPanel;
  @Inject private Wizard wizard;

  @BeforeClass
  public void setUp() throws Exception {
    ide.open(testWorkspace);
  }

  @Test
  public void commandPaletteTest() {
    // wait the jdt.ls server is started
    projectExplorer.waitProjectExplorer();
    consoles.waitExpectedTextIntoConsole("Started: Ready");

    // Create a java spring project
    menu.runCommand(Workspace.WORKSPACE, Workspace.CREATE_PROJECT);
    wizard.selectProjectAndCreate("kitchensink-example", PROJECT_NAME);
    notificationsPopupPanel.waitProgressPopupPanelClose();

    consoles.waitJDTLSProjectResolveFinishedMessage();

    // Open and close COP by hot keys
    commandsPalette.openCommandPaletteByHotKeys();
    commandsPalette.closeCommandPalette();

    // Start a command by Enter key
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByEnterKey(COMMAND);
    consoles.waitExpectedTextIntoConsole(BUILD_SUCCESS, EXPECTED_MESS_IN_CONSOLE_SEC);

    // Start a command by double click
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick(COMMAND);
    consoles.waitExpectedTextIntoConsole(BUILD_SUCCESS, EXPECTED_MESS_IN_CONSOLE_SEC);

    // Start commands from list after search
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick(COMMAND);
    consoles.waitExpectedTextIntoConsole(BUILD_SUCCESS, EXPECTED_MESS_IN_CONSOLE_SEC);

    // Select commands from keyboard navigation (arrow buttons and "Enter" button)
    commandsPalette.openCommandPalette();
    commandsPalette.moveAndStartCommand(CommandsPalette.MoveTypes.DOWN, 2);
    consoles.waitExpectedTextIntoConsole(BUILD_SUCCESS, EXPECTED_MESS_IN_CONSOLE_SEC);
  }

  @Test(priority = 1)
  public void newCommandTest() {
    projectExplorer.waitProjectExplorer();

    commandsBuilder(COMMON_GOAL, CUSTOM_TYPE);

    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick(customCommandName);
    consoles.waitExpectedTextIntoConsole("hello", EXPECTED_MESS_IN_CONSOLE_SEC);

    commandDelete(customCommandName);
    commandsPalette.openCommandPalette();
    commandsPalette.commandIsNotExists(customCommandName);
  }

  private void commandsBuilder(String goalName, String commandType) {
    commandsExplorer.openCommandsExplorer();
    commandsExplorer.waitCommandExplorerIsOpened();
    loader.waitOnClosed();
    commandsExplorer.clickAddCommandButton(goalName);
    loader.waitOnClosed();
    commandsExplorer.chooseCommandTypeInContextMenu(commandType);
    loader.waitOnClosed();
    commandsEditor.waitActive();
    commandsEditor.clickOnCancelCommandEditorButton();
    loader.waitOnClosed();
  }

  private void commandDelete(String commandName) {
    loader.waitOnClosed();
    commandsExplorer.clickOnRemoveButtonInExplorerByName(commandName);
    askDialog.waitFormToOpen();
    askDialog.confirmAndWaitClosed();
    loader.waitOnClosed();
    commandsExplorer.waitRemoveCommandFromExplorerByName(commandName);
  }
}
