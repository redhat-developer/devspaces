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

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.SPRING_BOOT;
import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.eclipse.che.selenium.core.constant.TestBuildConstants.BUILD_SUCCESS;
import static org.eclipse.che.selenium.core.constant.TestBuildConstants.LISTENING_AT_ADDRESS;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.BUILD_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.DEBUG_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.RUN_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.BUILD_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.RUN_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.BUILD_GOAL;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.DEBUG_GOAL;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.RUN_GOAL;

import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.CodereadyEditor;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import org.eclipse.che.selenium.core.client.TestProjectServiceClient;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.pageobject.AssistantFindPanel;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.FindReferencesConsoleTab;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.Menu;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.dashboard.AddOrImportForm;
import org.eclipse.che.selenium.pageobject.dashboard.CreateWorkspaceHelper;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceOverview;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.openqa.selenium.By;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/** @author Skoryk Serhii */
public class SpringBootUserStoryTest {

  private static final String WORKSPACE_NAME = generate("workspace", 4);
  private static final String SPRING_BOOT_HTTP_BOOSTER = "spring-boot-http-booster";

  @Inject private Ide ide;
  @Inject private Menu menu;
  @Inject private Consoles consoles;
  @Inject private Dashboard dashboard;
  @Inject private CodereadyEditor editor;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private AssistantFindPanel assistantFindPanel;
  @Inject private CreateWorkspaceHelper createWorkspaceHelper;
  @Inject private TestProjectServiceClient testProjectServiceClient;
  @Inject private FindReferencesConsoleTab findReferencesConsoleTab;
  @Inject private TestWorkspaceServiceClient workspaceServiceClient;

  @Inject private Workspaces workspaces;
  @Inject private WorkspaceOverview workspaceOverview;
  @Inject private CodereadyNewWorkspace newWorkspace;
  @Inject private AddOrImportForm addOrImportForm;

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
  public void createSpringBootWorkspaceWithProjectFromDashBoard() {
    dashboard.selectWorkspacesItemOnDashboard();
    dashboard.waitToolbarTitleName("Workspaces");
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.typeWorkspaceName(WORKSPACE_NAME);
    newWorkspace.selectCodereadyStack(SPRING_BOOT);
    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.addSampleToWorkspace(SPRING_BOOT_HTTP_BOOSTER);
    newWorkspace.clickOnCreateButtonAndOpenInIDE();

    ide.switchToIdeAndWaitWorkspaceIsReadyToUse();

    projectExplorer.waitProjectInitialization(SPRING_BOOT_HTTP_BOOSTER);

    consoles.waitJDTLSProjectResolveFinishedMessage(SPRING_BOOT_HTTP_BOOSTER);
  }

  @Test(priority = 1)
  public void checkSpringBootHealthCheckBoosterProjectCommands() {
    By textOnPreviewPage = By.xpath("//h2[text()='Health Check Booster']");

    // build and run 'spring-boot-health-check-booster' project
    consoles.executeCommandFromProjectExplorer(
        SPRING_BOOT_HTTP_BOOSTER, BUILD_GOAL, BUILD_COMMAND, BUILD_SUCCESS);

    consoles.executeCommandFromProjectExplorer(
        SPRING_BOOT_HTTP_BOOSTER,
        RUN_GOAL,
        BUILD_COMMAND_ITEM.getItem(SPRING_BOOT_HTTP_BOOSTER),
        BUILD_SUCCESS);

    consoles.executeCommandFromProjectExplorer(
        SPRING_BOOT_HTTP_BOOSTER,
        RUN_GOAL,
        RUN_COMMAND_ITEM.getItem(SPRING_BOOT_HTTP_BOOSTER),
        "Started BoosterApplication in");
    consoles.checkWebElementVisibilityAtPreviewPage(textOnPreviewPage);
    consoles.closeProcessTabWithAskDialog(RUN_COMMAND_ITEM.getItem(SPRING_BOOT_HTTP_BOOSTER));

    consoles.executeCommandFromProjectExplorer(
        SPRING_BOOT_HTTP_BOOSTER,
        RUN_GOAL,
        RUN_COMMAND,
        "INFO: Setting the server's publish address to be");
    consoles.checkWebElementVisibilityAtPreviewPage(textOnPreviewPage);
    consoles.closeProcessTabWithAskDialog(RUN_COMMAND);

    consoles.executeCommandFromProcessesArea(
        "dev-machine", DEBUG_GOAL, DEBUG_COMMAND, LISTENING_AT_ADDRESS);
    consoles.closeProcessTabWithAskDialog(DEBUG_COMMAND);
  }
}
