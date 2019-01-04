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

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.FUSE;
import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.eclipse.che.selenium.core.constant.TestBuildConstants.BUILD_SUCCESS;
import static org.eclipse.che.selenium.core.constant.TestBuildConstants.LISTENING_AT_ADDRESS_8000;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.BUILD_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.BUILD_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.DEBUG_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.RUN_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.ASSISTANT;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.QUICK_FIX;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.BUILD_GOAL;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.DEBUG_GOAL;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.RUN_GOAL;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;
import static org.openqa.selenium.Keys.F4;

import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.CodereadyEditor;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.core.workspace.TestWorkspaceProvider;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.Menu;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.dashboard.AddOrImportForm;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/** @author Skoryk Serhii */
public class RedHatFuseUserStoryTest {

  private static final String WORKSPACE_NAME = generate("workspace", 4);
  private static final String PROJECT_NAME = "spring-boot-camel";
  private static final String PATH_TO_MAIN_PACKAGE =
      PROJECT_NAME + "/src/main/java/io/fabric8/quickstarts/camel";
  private static final String LS_INIT_MESSAGE =
      "Initialized language server 'org.eclipse.che.plugin.camel.server.languageserver'";

  @Inject private Ide ide;
  @Inject private Menu menu;
  @Inject private Consoles consoles;
  @Inject private Dashboard dashboard;
  @Inject private Workspaces workspaces;
  @Inject private CodereadyEditor editor;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private AddOrImportForm addOrImportForm;
  @Inject private CodereadyNewWorkspace newWorkspace;
  @Inject private TestWorkspaceProvider testWorkspaceProvider;
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
  public void createRedHatFuseWorkspaceWithProjectFromDashboard() {
    createWorkspaceFromStackWithProject(FUSE, PROJECT_NAME);

    ide.switchToIdeAndWaitWorkspaceIsReadyToUse();
    testWorkspace = testWorkspaceProvider.getWorkspace(WORKSPACE_NAME, defaultTestUser);

    projectExplorer.waitProjectInitialization(PROJECT_NAME);

    // check Apache Camel language server initialized
    consoles.waitExpectedTextIntoConsole(LS_INIT_MESSAGE);

    consoles.waitJDTLSProjectResolveFinishedMessage(PROJECT_NAME);
  }

  @Test(priority = 1)
  public void checkSpringBootCamelProjectCommands() {
    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME, BUILD_GOAL, BUILD_COMMAND, BUILD_SUCCESS);

    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME, BUILD_GOAL, BUILD_COMMAND_ITEM.getItem(PROJECT_NAME), BUILD_SUCCESS);

    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME, RUN_GOAL, RUN_COMMAND_ITEM.getItem(PROJECT_NAME), "Hello World");

    consoles.closeProcessTabWithAskDialog(RUN_COMMAND_ITEM.getItem(PROJECT_NAME));

    consoles.executeCommandFromProcessesArea(
        "dev-machine",
        DEBUG_GOAL,
        DEBUG_COMMAND_ITEM.getItem(PROJECT_NAME),
        LISTENING_AT_ADDRESS_8000);
  }

  @Test(priority = 2)
  public void checkCodeAssistantFeatures() {
    projectExplorer.quickExpandWithJavaScript();

    projectExplorer.openItemByPath(PATH_TO_MAIN_PACKAGE + "/Application.java");
    editor.waitActive();

    checkGoToDeclarationFeature();
    checkCodeValidationFeature();
  }

  private void checkGoToDeclarationFeature() {
    editor.selectTabByName("Application");
    editor.goToPosition(28, 41);
    editor.typeTextIntoEditor(F4.toString());
    editor.waitActiveTabFileName("RouteBuilder.class");
    editor.waitCursorPosition(54, 35);
  }

  private void checkCodeValidationFeature() {
    editor.selectTabByName("Application");
    editor.goToPosition(32, 27);
    editor.typeTextIntoEditor("r");
    editor.waitMarkerInPosition(ERROR, 32);

    editor.goToPosition(32, 27);
    menu.runCommand(ASSISTANT, QUICK_FIX);
    editor.enterTextIntoFixErrorPropByDoubleClick("Change to 'run(..)'");
    editor.waitAllMarkersInvisibility(ERROR);
  }

  private void createWorkspaceFromStackWithProject(CodereadyStacks stackName, String projectName) {
    dashboard.selectWorkspacesItemOnDashboard();
    dashboard.waitToolbarTitleName("Workspaces");

    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.typeWorkspaceName(WORKSPACE_NAME);
    newWorkspace.selectCodereadyStack(stackName);
    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.addSampleToWorkspace(projectName);
    newWorkspace.clickOnCreateButtonAndOpenInIDE();
  }
}
