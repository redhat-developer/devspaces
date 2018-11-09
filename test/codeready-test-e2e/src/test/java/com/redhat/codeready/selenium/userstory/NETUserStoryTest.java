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
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.UPDATE_DEPENDENCIES_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.RUN_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.UPDATE_DEPENDENCIES_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.ASSISTANT;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.FIND_DEFINITION;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.GO_TO_SYMBOL;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.BUILD_GOAL;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.RUN_GOAL;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.INFO;
import static org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Stack.DOT_NET;
import static org.openqa.selenium.Keys.BACK_SPACE;
import static org.testng.Assert.fail;

import com.google.inject.Inject;
import java.net.URL;
import java.nio.file.Paths;
import org.eclipse.che.selenium.core.client.TestProjectServiceClient;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.project.ProjectTemplates;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.pageobject.AssistantFindPanel;
import org.eclipse.che.selenium.pageobject.CodenvyEditor;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.Menu;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.dashboard.CreateWorkspaceHelper;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.openqa.selenium.By;
import org.openqa.selenium.Keys;
import org.openqa.selenium.TimeoutException;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/** @author Skoryk Serhii */
public class NETUserStoryTest {

  private static final String WORKSPACE_NAME = generate("workspace", 4);
  private static final String PROJECT_NAME = "CSharpFileAdvancedOperations";
  private static final String SAMPLE_PROJECT_NAME = "dotnet-web-simple";
  private static final String PATH_TO_DOT_NET_FILE = PROJECT_NAME + "/Hello.cs";

  private String LANGUAGE_SERVER_INIT_MESSAGE =
      "Initialized language server 'org.eclipse.che.plugin.csharp.languageserver";
  private String NAME_OF_EDITING_FILE = "Program.cs";

  @Inject private Ide ide;
  @Inject private Consoles consoles;
  @Inject private Dashboard dashboard;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private Menu menu;
  @Inject private CodenvyEditor editor;
  @Inject private CreateWorkspaceHelper createWorkspaceHelper;
  @Inject private AssistantFindPanel assistantFindPanel;
  @Inject private TestProjectServiceClient testProjectServiceClient;
  @Inject private TestWorkspaceServiceClient workspaceServiceClient;

  // it is used to read workspace logs on test failure
  private TestWorkspace testWorkspace;

  @BeforeClass
  public void setUp() {
    dashboard.open();
  }

  @AfterClass
  public void tearDown() throws Exception {
    workspaceServiceClient.delete(WORKSPACE_NAME, defaultTestUser.getName());
  }

  @Test
  public void checkWorkspaceCreationFromNETStack() {
    // store info about created workspace to make SeleniumTestHandler.captureTestWorkspaceLogs()
    // possible to read logs in case of test failure
    testWorkspace =
        createWorkspaceHelper.createWorkspaceFromStackWithProject(
            DOT_NET, WORKSPACE_NAME, SAMPLE_PROJECT_NAME);

    ide.switchToIdeAndWaitWorkspaceIsReadyToUse();

    projectExplorer.waitProjectInitialization(SAMPLE_PROJECT_NAME);
  }

  @Test(priority = 1)
  public void checkDotnetWebSimpleProjectCommands() {
    By textOnPreviewPage = By.xpath("//pre[text()='Hello World!']");

    consoles.executeCommandFromProjectExplorer(
        SAMPLE_PROJECT_NAME, BUILD_GOAL, UPDATE_DEPENDENCIES_COMMAND, "Restore completed");
    consoles.executeCommandFromProjectExplorer(
        SAMPLE_PROJECT_NAME,
        BUILD_GOAL,
        UPDATE_DEPENDENCIES_COMMAND_ITEM.getItem(SAMPLE_PROJECT_NAME),
        "Restore completed");

    consoles.executeCommandFromProjectExplorer(
        SAMPLE_PROJECT_NAME, RUN_GOAL, RUN_COMMAND, "Application started.");
    consoles.checkWebElementVisibilityAtPreviewPage(textOnPreviewPage);
    consoles.closeProcessTabWithAskDialog("run");

    consoles.executeCommandFromProjectExplorer(
        SAMPLE_PROJECT_NAME,
        RUN_GOAL,
        RUN_COMMAND_ITEM.getItem(SAMPLE_PROJECT_NAME),
        "Application started.");
    consoles.checkWebElementVisibilityAtPreviewPage(textOnPreviewPage);
  }

  @Test(priority = 2)
  public void checkBasicPythonLanguageServerFeatures() throws Exception {
    URL resource = getClass().getResource("/projects/CSharpFileAdvancedOperations");
    testProjectServiceClient.importProject(
        testWorkspace.getId(),
        Paths.get(resource.toURI()),
        "CSharpFileAdvancedOperations",
        ProjectTemplates.DOT_NET);

    initLanguageServer();

    projectExplorer.openItemByPath(PROJECT_NAME);
    projectExplorer.openItemByPath(PATH_TO_DOT_NET_FILE);

    // after opening the file we are checking initializing message from LS and than check, that
    // dependencies have been added properly in this case
    // folders obj and bin should appear in the Project tree
    consoles.waitExpectedTextIntoConsole(LANGUAGE_SERVER_INIT_MESSAGE);
    projectExplorer.waitItem(PROJECT_NAME + "/obj");
    projectExplorer.waitItem(PROJECT_NAME + "/bin");

    //    checkCodeValidation();
    checkHoveringFeature();
    checkFindDefinition();
    checkCodeCommentFeature();
    checkGoToSymbolFeature();
  }

  public void checkHoveringFeature() {
    String expectedTextInHoverPopUp =
        "System.Console\nRepresents the standard input, output, and error streams for console applications. This class cannot be inherited.";

    editor.moveCursorToText("Console");
    editor.waitTextInHoverPopUpEqualsTo(expectedTextInHoverPopUp);
  }

  public void checkFindDefinition() {
    // check Find definition from Test.getStr()
    editor.goToCursorPositionVisible(21, 18);
    menu.runCommand(ASSISTANT, FIND_DEFINITION);
    editor.waitTabIsPresent("Test.cs");
    editor.waitCursorPosition(18, 22);
  }

  public void checkCodeCommentFeature() {
    editor.goToPosition(17, 1);
    editor.launchCommentCodeFeature();
    editor.waitTextIntoEditor("//private counter = 5;");
    editor.typeTextIntoEditor(Keys.END.toString());
  }

  public void checkGoToSymbolFeature() {
    menu.runCommand(ASSISTANT, GO_TO_SYMBOL);
    try {
      assistantFindPanel.waitNode("Main(string[] args)");
    } catch (TimeoutException ex) {
      // remove try-catch block after issue has been resolved
      fail("Known permanent failure: https://github.com/eclipse/che/issues/11258", ex);
    }
  }

  public void checkCodeValidation() {
    editor.goToCursorPositionVisible(24, 12);
    for (int i = 0; i < 9; i++) {
      editor.typeTextIntoEditor(BACK_SPACE.toString());
    }

    try {
      editor.waitMarkerInPosition(INFO, 23);
    } catch (TimeoutException ex) {
      fail("Known random failure https://github.com/eclipse/che/issues/10789", ex);
    }

    editor.waitMarkerInPosition(ERROR, 21);
    checkAutocompletion();
  }

  private void initLanguageServer() {
    projectExplorer.quickRevealToItemWithJavaScript(
        SAMPLE_PROJECT_NAME + "/" + NAME_OF_EDITING_FILE);
    projectExplorer.openItemByPath(SAMPLE_PROJECT_NAME + "/" + NAME_OF_EDITING_FILE);
    consoles.selectProcessByTabName("dev-machine");
    consoles.waitExpectedTextIntoConsole(LANGUAGE_SERVER_INIT_MESSAGE);
    editor.selectTabByName(NAME_OF_EDITING_FILE);
  }

  private void checkAutocompletion() {
    editor.goToCursorPositionVisible(23, 49);
    editor.typeTextIntoEditor(".");
    editor.launchAutocomplete();
    editor.enterAutocompleteProposal("Build ");
    editor.typeTextIntoEditor("();");
    editor.waitAllMarkersInvisibility(ERROR);
  }
}
