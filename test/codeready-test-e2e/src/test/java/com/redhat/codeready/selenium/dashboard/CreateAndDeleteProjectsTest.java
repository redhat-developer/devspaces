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
package com.redhat.codeready.selenium.dashboard;

import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.eclipse.che.selenium.pageobject.ProjectExplorer.FolderTypes.PROJECT_FOLDER;
import static org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Stack.JAVA;
import static org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceDetails.WorkspaceDetailsTab.PROJECTS;
import static org.testng.Assert.fail;

import com.google.inject.Inject;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.core.workspace.TestWorkspaceProvider;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.MavenPluginStatusBar;
import org.eclipse.che.selenium.pageobject.NotificationsPopupPanel;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.ToastLoader;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace;
import org.eclipse.che.selenium.pageobject.dashboard.ProjectSourcePage;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceDetails;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceProjects;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.openqa.selenium.TimeoutException;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/** @author Andrey Chizhikov */
public class CreateAndDeleteProjectsTest {

  private static final String WORKSPACE = generate("workspace", 4);
  private static final String KITCHENSINK_EXAMPLE = "kitchensink-example";
  private static final String SECOND_KINTCHENSINK_PROJECT_NAME = KITCHENSINK_EXAMPLE + "-1";

  private String dashboardWindow;

  @Inject private Dashboard dashboard;
  @Inject private WorkspaceProjects workspaceProjects;
  @Inject private WorkspaceDetails workspaceDetails;
  @Inject private NewWorkspace newWorkspace;
  @Inject private ProjectSourcePage projectSourcePage;
  @Inject private ProjectExplorer explorer;
  @Inject private SeleniumWebDriver seleniumWebDriver;
  @Inject private SeleniumWebDriverHelper seleniumWebDriverHelper;
  @Inject private TestWorkspaceServiceClient workspaceServiceClient;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private NotificationsPopupPanel notificationsPopupPanel;
  @Inject private MavenPluginStatusBar mavenPluginStatusBar;
  @Inject private Workspaces workspaces;
  @Inject private Ide ide;
  @Inject private ToastLoader toastLoader;
  @Inject private TestWorkspaceProvider testWorkspaceProvider;

  // it is used to read workspace logs on test failure
  private TestWorkspace testWorkspace;

  @BeforeClass
  public void setUp() {
    dashboard.open();
  }

  @AfterClass
  public void tearDown() throws Exception {
    workspaceServiceClient.delete(WORKSPACE, defaultTestUser.getName());
  }

  @Test
  public void createProjectTest() {
    dashboard.waitDashboardToolbarTitle();
    dashboard.selectWorkspacesItemOnDashboard();
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.waitToolbar();

    newWorkspace.clickOnAllStacksTab();
    newWorkspace.selectStack(JAVA);
    newWorkspace.typeWorkspaceName(WORKSPACE);

    // create 'kitchensink-example' project
    projectSourcePage.clickOnAddOrImportProjectButton();
    projectSourcePage.selectSample(KITCHENSINK_EXAMPLE);
    projectSourcePage.clickOnAddProjectButton();

    // create 'kitchensink-example-1' project
    projectSourcePage.clickOnAddOrImportProjectButton();
    projectSourcePage.selectSample(KITCHENSINK_EXAMPLE);
    projectSourcePage.clickOnAddProjectButton();

    newWorkspace.clickOnCreateButtonAndOpenInIDE();
    // store info about created workspace to make SeleniumTestHandler.captureTestWorkspaceLogs()
    // possible to read logs in case of test failure
    testWorkspace = testWorkspaceProvider.getWorkspace(WORKSPACE, defaultTestUser);

    // switch to the IDE and wait for workspace is ready to use
    dashboardWindow = seleniumWebDriverHelper.switchToIdeFrameAndWaitAvailability();
    toastLoader.waitToastLoaderAndClickStartButton();
    ide.waitOpenedWorkspaceIsReadyToUse();

    // wait for projects initializing
    explorer.waitItem(KITCHENSINK_EXAMPLE);
    explorer.waitItem(SECOND_KINTCHENSINK_PROJECT_NAME);
    notificationsPopupPanel.waitPopupPanelsAreClosed();
    mavenPluginStatusBar.waitClosingInfoPanel();
    explorer.waitDefinedTypeOfFolder(KITCHENSINK_EXAMPLE, PROJECT_FOLDER);
    notificationsPopupPanel.waitPopupPanelsAreClosed();
  }

  @Test
  public void deleteProjectsFromDashboardTest() {
    // delete projects from workspace details page
    switchToWindow(dashboardWindow);
    dashboard.selectWorkspacesItemOnDashboard();
    workspaces.selectWorkspaceItemName(WORKSPACE);
    workspaceDetails.selectTabInWorkspaceMenu(PROJECTS);
    workspaceProjects.waitProjectIsPresent(KITCHENSINK_EXAMPLE);

    openProjectSettings(KITCHENSINK_EXAMPLE);
    workspaceProjects.clickOnDeleteProject();
    workspaceProjects.clickOnDeleteItInDialogWindow();
    workspaceProjects.waitProjectIsNotPresent(KITCHENSINK_EXAMPLE);
    workspaceProjects.waitProjectIsPresent(SECOND_KINTCHENSINK_PROJECT_NAME);
  }

  private void switchToWindow(String windowHandle) {
    seleniumWebDriver.switchTo().window(windowHandle);
  }

  private void openProjectSettings(String projectName) {
    try {
      workspaceProjects.openSettingsForProjectByName(projectName);
    } catch (TimeoutException ex) {
      // remove try-catch block after issue has been resolved
      fail("Known random failure https://github.com/eclipse/che/issues/8931");
    }
  }
}
