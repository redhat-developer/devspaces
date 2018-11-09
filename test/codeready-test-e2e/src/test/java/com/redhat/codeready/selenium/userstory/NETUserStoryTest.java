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
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.BUILD_GOAL;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.RUN_GOAL;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.INFO;
import static org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Stack.DOT_NET;

import com.google.inject.Inject;
import org.eclipse.che.selenium.core.client.TestProjectServiceClient;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
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
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/** @author Skoryk Serhii */
public class NETUserStoryTest {

  private static final String WORKSPACE_NAME = generate("workspace", 4);
  private static final String PROJECT_NAME = "dotnet-web-simple";

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
            DOT_NET, WORKSPACE_NAME, PROJECT_NAME);

    ide.switchToIdeAndWaitWorkspaceIsReadyToUse();

    projectExplorer.waitProjectInitialization(PROJECT_NAME);
  }

  @Test(priority = 1)
  public void checkDotnetWebSimpleProjectCommands() {
    By textOnPreviewPage = By.xpath("//pre[text()='Hello World!']");

    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME, BUILD_GOAL, UPDATE_DEPENDENCIES_COMMAND, "Restore completed");
    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME,
        BUILD_GOAL,
        UPDATE_DEPENDENCIES_COMMAND_ITEM.getItem(PROJECT_NAME),
        "Restore completed");

    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME, RUN_GOAL, RUN_COMMAND, "Application started.");
    consoles.checkWebElementVisibilityAtPreviewPage(textOnPreviewPage);
    consoles.closeProcessTabWithAskDialog("run");

    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME, RUN_GOAL, RUN_COMMAND_ITEM.getItem(PROJECT_NAME), "Application started.");
    consoles.checkWebElementVisibilityAtPreviewPage(textOnPreviewPage);
  }

  @Test(priority = 2)
  public void checkBasicCSharpLanguageServerFeatures() {
    initLanguageServer();

    checkCodeValidation();
    checkAutocompleteFeature();
  }

  public void checkHoveringFeature() {
    String expectedTextInHoverPopUp =
        "Microsoft.AspNetCore.Hosting.IWebHost Represents a configured web host.";

    editor.moveCursorToText(" IWebHost ");
    editor.waitTextInHoverPopup(expectedTextInHoverPopUp);
  }

  public void checkCodeCommentFeature() {
    editor.goToPosition(13, 1);
    editor.launchCommentCodeFeature();
    editor.waitTextIntoEditor("//    public class Program");

    editor.launchCommentCodeFeature();
    editor.waitAllMarkersInvisibility(ERROR);
  }

  public void checkCodeValidation() {
    // TODO check code validation
    editor.waitAllMarkersInvisibility(ERROR);
    editor.goToPosition(24, 12);
    editor.typeTextIntoEditor(Keys.BACK_SPACE.toString());
    editor.waitMarkerInPosition(ERROR, 24);

    editor.goToPosition(24, 11);
    editor.typeTextIntoEditor(";");
    editor.waitMarkerInvisibility(ERROR, 24);
  }

  private void checkAutocompleteFeature() {
    editor.deleteCurrentLineAndInsertNew();

    editor.goToCursorPositionVisible(23, 49);
    editor.typeTextIntoEditor(".");
    editor.launchAutocomplete();
    editor.enterAutocompleteProposal("Build ");
    editor.typeTextIntoEditor("();");
    editor.waitAllMarkersInvisibility(ERROR);
  }

  private void initLanguageServer() {
    projectExplorer.quickRevealToItemWithJavaScript(PROJECT_NAME + "/" + NAME_OF_EDITING_FILE);
    projectExplorer.openItemByPath(PROJECT_NAME + "/" + NAME_OF_EDITING_FILE);

    projectExplorer.waitItem(PROJECT_NAME + "/obj");
    projectExplorer.waitItem(PROJECT_NAME + "/bin");

    consoles.selectProcessByTabName("dev-machine");
    consoles.waitExpectedTextIntoConsole(LANGUAGE_SERVER_INIT_MESSAGE);

    editor.closeAllTabs();

    projectExplorer.openItemByPath(PROJECT_NAME + "/" + NAME_OF_EDITING_FILE);
    editor.waitActive();
    editor.waitCodeAssistMarkers(INFO);
  }
}
