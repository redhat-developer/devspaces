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

import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.RUN_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.BUILD_AND_RUN_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.RUN_GOAL;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.WIDGET_TIMEOUT_SEC;
import static org.eclipse.che.selenium.core.utils.FileUtil.readFileToString;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;

import com.google.common.collect.ImmutableList;
import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.dashboard.CodeReadyCreateWorkspaceHelper;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import java.io.IOException;
import java.net.URISyntaxException;
import java.util.List;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.pageobject.CodenvyEditor;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.openqa.selenium.Keys;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/**
 * @author Skoryk Serhii
 * @author Aleksandr Shmaraiev
 */
public class ClangCppUserStoryTest {
  private static final String WORKSPACE_NAME = generate("workspace", 4);
  private static final String CONSOLE_CPP_PROJECT = "console-cpp-simple";
  private static final String C_SIMPLE_CONSOLE_PROJECT = "c-simple-console";
  private static final String CPP_FILE_NAME = "hello.cc";
  private static final String PATH_TO_CPP_FILE = CONSOLE_CPP_PROJECT + "/" + CPP_FILE_NAME;
  private static final String EXPECTED_MESSAGE_IN_CONSOLE = "Hello World";
  private List<String> projects = ImmutableList.of(CONSOLE_CPP_PROJECT, C_SIMPLE_CONSOLE_PROJECT);

  @Inject private Ide ide;
  @Inject private Consoles consoles;
  @Inject private Dashboard dashboard;
  @Inject private CodenvyEditor editor;
  @Inject private CodeReadyCreateWorkspaceHelper codeReadyCreateWorkspaceHelper;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private TestWorkspaceServiceClient workspaceServiceClient;
  @Inject private SeleniumWebDriver seleniumWebDriver;

  // it is used to read workspace logs on test failure
  private TestWorkspace testWorkspace;
  private String addressImage;

  @BeforeClass
  public void setUp() throws IOException, URISyntaxException {
    dashboard.open();
    addressImage = readFileToString(getClass().getResource("/crw-stage-images/cpp-stack.txt"));
  }

  @AfterClass
  public void tearDown() throws Exception {
    workspaceServiceClient.delete(WORKSPACE_NAME, defaultTestUser.getName());
  }

  @Test
  public void checkWorkspaceCreationFromCppStack() {
    // store info about created workspace to make SeleniumTestHandler.captureTestWorkspaceLogs()
    // possible to read logs in case of test failure
    testWorkspace =
        codeReadyCreateWorkspaceHelper.createWsFromStackWithTestProject(
            WORKSPACE_NAME, CodereadyNewWorkspace.CodereadyStacks.CPP, addressImage, projects);

    ide.switchToIdeAndWaitWorkspaceIsReadyToUse();

    projectExplorer.waitProjectInitialization(CONSOLE_CPP_PROJECT);
    projectExplorer.waitProjectInitialization(C_SIMPLE_CONSOLE_PROJECT);
    expandCppProjectAndOpenFile();
  }

  @Test(priority = 1)
  public void checkConsoleCppSimpleProjectCommands() {
    consoles.executeCommandFromProjectExplorer(
        CONSOLE_CPP_PROJECT, RUN_GOAL, RUN_COMMAND, EXPECTED_MESSAGE_IN_CONSOLE);

    consoles.executeCommandFromProjectExplorer(
        CONSOLE_CPP_PROJECT,
        RUN_GOAL,
        BUILD_AND_RUN_COMMAND_ITEM.getItem(CONSOLE_CPP_PROJECT),
        EXPECTED_MESSAGE_IN_CONSOLE);
  }

  @Test(priority = 1)
  public void checkClangSimpleConsoleProjectCommands() {
    consoles.executeCommandFromProjectExplorer(
        C_SIMPLE_CONSOLE_PROJECT,
        RUN_GOAL,
        BUILD_AND_RUN_COMMAND_ITEM.getItem(C_SIMPLE_CONSOLE_PROJECT),
        EXPECTED_MESSAGE_IN_CONSOLE);
  }

  @Test(priority = 2)
  public void checkAutocompleteFeature() {
    editor.selectTabByName(CPP_FILE_NAME);

    // check contents of autocomplete container
    editor.goToPosition(7, 44);
    editor.typeTextIntoEditor(Keys.ENTER.toString());
    editor.typeTextIntoEditor("std::cou");
    editor.launchAutocompleteAndWaitContainer();
    editor.waitProposalIntoAutocompleteContainer("cout ostream");
    editor.waitProposalIntoAutocompleteContainer("wcout wostream");
    editor.closeAutocomplete();

    editor.deleteCurrentLine();
  }

  @Test(priority = 3)
  public void checkRenameFieldFeature() {
    editor.selectTabByName(CPP_FILE_NAME);
    editor.setCursorToLine(4);
    editor.typeTextIntoEditor("int isEven(int arg);");
    editor.waitTextIntoEditor("int isEven(int arg);");

    // perform renaming
    editor.goToPosition(4, 17);
    editor.launchLocalRefactor();
    editor.doRenamingByLanguageServerField("args");
    editor.waitTextIntoEditor("int isEven(int args);");
    editor.waitAllMarkersInvisibility(ERROR);
  }

  @Test(priority = 3)
  public void checkCodeValidation() {
    editor.selectTabByName(CPP_FILE_NAME);
    editor.waitActive();

    // make error in code and check error marker with message
    editor.waitAllMarkersInvisibility(ERROR);
    editor.goToCursorPositionVisible(5, 1);
    editor.typeTextIntoEditor("c");
    editor.waitMarkerInPosition(ERROR, 5);
    editor.moveCursorToText("cint");
    editor.waitTextInHoverPopup("unknown type name 'cint'");

    // restore content and check error marker invisibility
    editor.goToCursorPositionVisible(5, 1);
    editor.typeTextIntoEditor(Keys.DELETE.toString());
    editor.waitAllMarkersInvisibility(ERROR);
  }

  private void expandCppProjectAndOpenFile() {
    projectExplorer.waitAndSelectItem(CONSOLE_CPP_PROJECT);
    projectExplorer.openItemByPath(CONSOLE_CPP_PROJECT);
    projectExplorer.openItemByPath(PATH_TO_CPP_FILE);
    editor.waitActive(WIDGET_TIMEOUT_SEC);
    editor.waitTabIsPresent(CPP_FILE_NAME);
  }
}
