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
package com.redhat.codeready.selenium.dashboard.workspaces;

import static java.util.Arrays.asList;
import static org.eclipse.che.selenium.core.TestGroup.UNDER_REPAIR;
import static org.eclipse.che.selenium.core.project.ProjectTemplates.MAVEN_SPRING;
import static org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Stack.JAVA;
import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertTrue;
import static org.testng.Assert.fail;

import com.google.inject.Inject;
import java.net.URL;
import java.nio.file.Paths;
import java.util.List;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.client.TestProjectServiceClient;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.workspace.InjectTestWorkspace;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.DocumentationPage;
import org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceConfig;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceOverview;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceProjects;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces.Status;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.BeforeMethod;
import org.testng.annotations.Test;

/**
 * @author Sergey Skorik
 * @author Ihor Okhrimenko
 */
public class WorkspacesListTest {
  private static final int NODE_WS_MB = 2048;
  private static final int JAVA_WS_MB = 3072;
  private static final int NODE_WS_PROJECTS_COUNT = 0;
  private static final int JAVA_WS_PROJECTS_COUNT = 1;
  private static final String EXPECTED_DOCUMENTATION_PAGE_TITLE = "What Is a Che Workspace?";
  private static final String EXPECTED_JAVA_PROJECT_NAME = "web-java-spring";
  private static final String NEWEST_CREATED_WORKSPACE_NAME = "just-created-workspace";
  private static final int EXPECTED_SORTED_WORKSPACES_COUNT = 1;

  @Inject private Dashboard dashboard;
  @Inject private WorkspaceProjects workspaceProjects;
  @Inject private WorkspaceConfig workspaceConfig;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private Workspaces workspaces;
  @Inject private NewWorkspace newWorkspace;
  @Inject private TestProjectServiceClient testProjectServiceClient;
  @Inject private TestWorkspaceServiceClient testWorkspaceServiceClient;
  @Inject private SeleniumWebDriverHelper seleniumWebDriverHelper;
  @Inject private SeleniumWebDriver seleniumWebDriver;
  @Inject private DocumentationPage documentationPage;
  @Inject private WorkspaceOverview workspaceOverview;

  @InjectTestWorkspace(memoryGb = 2, startAfterCreation = false)
  private TestWorkspace nodeWorkspace;

  @InjectTestWorkspace(memoryGb = 2, startAfterCreation = false)
  private TestWorkspace workspaceToDelete;

  @InjectTestWorkspace(memoryGb = 2)
  private TestWorkspace javaWorkspace;

  private Workspaces.WorkspaceListItem expectedNodeItem;
  private Workspaces.WorkspaceListItem expectedJavaItem;
  private Workspaces.WorkspaceListItem expectedNewestWorkspaceItem;

  @BeforeClass
  public void setUp() throws Exception {
    URL resource = getClass().getResource("/projects/defaultSpringProjectWithDifferentTypeOfFiles");

    testProjectServiceClient.importProject(
        javaWorkspace.getId(), Paths.get(resource.toURI()), "web-java-spring", MAVEN_SPRING);

    expectedNodeItem =
        new Workspaces.WorkspaceListItem(
            defaultTestUser.getName(), nodeWorkspace.getName(), NODE_WS_MB, NODE_WS_PROJECTS_COUNT);

    expectedJavaItem =
        new Workspaces.WorkspaceListItem(
            defaultTestUser.getName(), javaWorkspace.getName(), JAVA_WS_MB, JAVA_WS_PROJECTS_COUNT);

    expectedNewestWorkspaceItem =
        new Workspaces.WorkspaceListItem(
            defaultTestUser.getName(),
            NEWEST_CREATED_WORKSPACE_NAME,
            NODE_WS_MB,
            NODE_WS_PROJECTS_COUNT);

    dashboard.open();
  }

  @BeforeMethod
  public void prepareToTestMethod() {
    dashboard.waitDashboardToolbarTitle();
    dashboard.selectWorkspacesItemOnDashboard();
  }

  @AfterClass
  public void tearDown() throws Exception {
    testWorkspaceServiceClient.delete(
        expectedNewestWorkspaceItem.getWorkspaceName(), defaultTestUser.getName());
  }

  @Test
  public void shouldDisplayElements() throws Exception {
    workspaces.waitPageLoading();
    dashboard.waitWorkspacesCountInWorkspacesItem(getWorkspacesCount());

    checkExpectedNodeWorkspaceDisplaying();

    checkExpectedJavaWorkspaceDisplaying();
  }

  @Test
  public void checkWorkspaceSelectingByCheckbox() throws Exception {
    String blankWorkspaceName = nodeWorkspace.getName();
    String javaWorkspaceName = javaWorkspace.getName();

    workspaces.waitPageLoading();

    // select all by bulk
    workspaces.selectAllWorkspacesByBulk();
    workspaces.waitWorkspaceCheckboxEnabled(javaWorkspaceName);
    workspaces.waitWorkspaceCheckboxEnabled(blankWorkspaceName);
    workspaces.waitBulkCheckboxEnabled();
    workspaces.waitDeleteWorkspaceBtn();

    // unselect all by bulk
    workspaces.selectAllWorkspacesByBulk();
    workspaces.waitWorkspaceCheckboxDisabled(javaWorkspaceName);
    workspaces.waitWorkspaceCheckboxDisabled(blankWorkspaceName);
    workspaces.waitBulkCheckboxDisabled();
    workspaces.waitDeleteWorkspaceBtnDisappearance();

    // select all by bulk
    workspaces.selectAllWorkspacesByBulk();
    workspaces.waitWorkspaceCheckboxEnabled(javaWorkspaceName);
    workspaces.waitWorkspaceCheckboxEnabled(blankWorkspaceName);
    workspaces.waitBulkCheckboxEnabled();
    workspaces.waitDeleteWorkspaceBtn();

    // unselect one checkbox
    workspaces.selectWorkspaceByCheckbox(blankWorkspaceName);
    workspaces.waitWorkspaceCheckboxEnabled(javaWorkspaceName);
    workspaces.waitWorkspaceCheckboxDisabled(blankWorkspaceName);
    workspaces.waitBulkCheckboxDisabled();
    workspaces.waitDeleteWorkspaceBtn();

    // unselect all checkboxes
    workspaces.selectWorkspaceByCheckbox(javaWorkspaceName);
    workspaces.waitWorkspaceCheckboxDisabled(javaWorkspaceName);
    workspaces.waitWorkspaceCheckboxDisabled(blankWorkspaceName);
    workspaces.waitBulkCheckboxDisabled();

    // for avoid of failing in the multi-thread mode when unexpected workspaces can appear in the
    // workspaces list
    workspaces.clickOnUnexpectedWorkspacesCheckboxes(asList(blankWorkspaceName, javaWorkspaceName));

    workspaces.waitDeleteWorkspaceBtnDisappearance();

    // select one checkbox
    workspaces.selectWorkspaceByCheckbox(blankWorkspaceName);
    workspaces.waitWorkspaceCheckboxDisabled(javaWorkspaceName);
    workspaces.waitWorkspaceCheckboxEnabled(blankWorkspaceName);
    workspaces.waitBulkCheckboxDisabled();
    workspaces.waitDeleteWorkspaceBtn();

    // select all checkboxes
    workspaces.selectWorkspaceByCheckbox(javaWorkspaceName);
    workspaces.waitWorkspaceCheckboxEnabled(javaWorkspaceName);
    workspaces.waitWorkspaceCheckboxEnabled(blankWorkspaceName);

    // for avoid of failing in the multi-thread mode
    workspaces.clickOnUnexpectedWorkspacesCheckboxes(asList(blankWorkspaceName, javaWorkspaceName));

    workspaces.waitBulkCheckboxEnabled();
    workspaces.waitDeleteWorkspaceBtn();

    // unselect all by bulk
    workspaces.selectAllWorkspacesByBulk();
    workspaces.waitWorkspaceCheckboxDisabled(javaWorkspaceName);
    workspaces.waitWorkspaceCheckboxDisabled(blankWorkspaceName);
    workspaces.waitBulkCheckboxDisabled();
    workspaces.waitDeleteWorkspaceBtnDisappearance();
  }

  @Test(groups = UNDER_REPAIR)
  public void checkSorting() {
    workspaces.waitPageLoading();
    workspaces.clickOnRamButton();

    List<Workspaces.WorkspaceListItem> items = workspaces.getVisibleWorkspaces();

    // items are sorted by name, check is present for ensuring of items order
    if (items.get(0).getRamAmount() != NODE_WS_MB) {
      workspaces.clickOnRamButton();
      items = workspaces.getVisibleWorkspaces();
    }

    // check items order after "RAM" clicking
    try {
      assertEquals(items.get(0).getRamAmount(), NODE_WS_MB);
      assertEquals(items.get(1).getRamAmount(), JAVA_WS_MB);
    } catch (AssertionError ex) {
      // remove try-catch block after issue has been resolved
      fail("Known permanent failure https://github.com/eclipse/che/issues/4242");
    }

    // check reverse order after "RAM" clicking
    workspaces.clickOnRamButton();
    items = workspaces.getVisibleWorkspaces();
    try {
      assertEquals(items.get(0).getRamAmount(), JAVA_WS_MB);
      assertEquals(items.get(1).getRamAmount(), NODE_WS_MB);
    } catch (AssertionError ex) {
      // remove try-catch block after issue has been resolved
      fail("Known permanent failure https://github.com/eclipse/che/issues/4242");
    }

    // check items order after "Projects" clicking
    workspaces.clickOnProjectsButton();
    items = workspaces.getVisibleWorkspaces();
    assertEquals(items.get(0).getProjectsAmount(), NODE_WS_PROJECTS_COUNT);
    assertEquals(items.get(1).getProjectsAmount(), JAVA_WS_PROJECTS_COUNT);

    // check items reverse order after "Projects" clicking
    workspaces.clickOnProjectsButton();
    items = workspaces.getVisibleWorkspaces();
    assertEquals(items.get(0).getProjectsAmount(), JAVA_WS_PROJECTS_COUNT);
    assertEquals(items.get(1).getProjectsAmount(), NODE_WS_PROJECTS_COUNT);
  }

  @Test
  public void checkSearchField() throws Exception {
    int nameLength = expectedNodeItem.getWorkspaceName().length();
    int existingWorkspacesCount = getWorkspacesCount();
    String sequenceForSearch =
        expectedNodeItem.getWorkspaceName().substring(nameLength - 5, nameLength);

    workspaces.waitVisibleWorkspacesCount(existingWorkspacesCount);

    workspaces.typeToSearchInput(sequenceForSearch);
    workspaces.waitVisibleWorkspacesCount(EXPECTED_SORTED_WORKSPACES_COUNT);
    List<Workspaces.WorkspaceListItem> items = workspaces.getVisibleWorkspaces();
    assertEquals(items.get(0).getWorkspaceName(), expectedNodeItem.getWorkspaceName());

    // check displaying list size
    workspaces.typeToSearchInput("");
    workspaces.waitVisibleWorkspacesCount(getWorkspacesCount());

    // check that expected blank and java items are displaying, in sum with previous items count
    // checking it gives a full workspaces list checking
    checkExpectedNodeWorkspaceDisplaying();
    checkExpectedJavaWorkspaceDisplaying();
  }

  @Test
  public void checkWorkspaceActions() throws Exception {
    workspaces.waitPageLoading();

    // go to workspace details by clicking on item in workspaces list
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.waitPageLoad();

    seleniumWebDriver.navigate().back();

    workspaces.waitPageLoading();

    workspaces.clickOnWorkspaceListItem(
        defaultTestUser.getName(), expectedNodeItem.getWorkspaceName());

    workspaceOverview.checkNameWorkspace(expectedNodeItem.getWorkspaceName());

    seleniumWebDriver.navigate().back();

    // check "Add project" button
    workspaces.waitPageLoading();

    workspaces.moveCursorToWorkspaceRamSection(expectedJavaItem.getWorkspaceName());
    workspaces.clickOnWorkspaceAddProjectButton(expectedJavaItem.getWorkspaceName());

    workspaceProjects.waitProjectIsPresent(EXPECTED_JAVA_PROJECT_NAME);

    seleniumWebDriver.navigate().back();

    // check "Workspace configuration" button
    workspaces.waitPageLoading();

    workspaces.moveCursorToWorkspaceRamSection(expectedJavaItem.getWorkspaceName());
    workspaces.clickOnWorkspaceConfigureButton(expectedJavaItem.getWorkspaceName());
    workspaceConfig.waitConfigForm();

    seleniumWebDriver.navigate().back();

    // check stop/start button
    workspaces.waitPageLoading();

    workspaces.moveCursorToWorkspaceRamSection(expectedJavaItem.getWorkspaceName());
    workspaces.clickOnWorkspaceStopStartButton(expectedJavaItem.getWorkspaceName());
    workspaces.waitWorkspaceStatus(expectedJavaItem.getWorkspaceName(), Status.STOPPED);

    workspaces.clickOnWorkspaceStopStartButton(expectedJavaItem.getWorkspaceName());
    workspaces.waitWorkspaceStatus(expectedJavaItem.getWorkspaceName(), Status.RUNNING);

    // check adding the workspace to list
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.waitToolbar();
    newWorkspace.typeWorkspaceName(NEWEST_CREATED_WORKSPACE_NAME);
    newWorkspace.selectStack(JAVA);
    newWorkspace.clickOnCreateButtonAndEditWorkspace();
    workspaceOverview.checkNameWorkspace(NEWEST_CREATED_WORKSPACE_NAME);

    dashboard.selectWorkspacesItemOnDashboard();

    workspaces.waitPageLoading();
    workspaces.waitVisibleWorkspacesCount(getWorkspacesCount());

    Workspaces.WorkspaceListItem newestCreatedWorkspaceItem =
        workspaces.getWorkspacesListItemByWorkspaceName(
            workspaces.getVisibleWorkspaces(), NEWEST_CREATED_WORKSPACE_NAME);

    assertTrue(newestCreatedWorkspaceItem.equals(expectedNewestWorkspaceItem));
  }

  @Test
  public void deleteWorkspacesByCheckboxes() throws Exception {
    workspaces.waitPageLoading();

    workspaces.selectWorkspaceByCheckbox(workspaceToDelete.getName());
    workspaces.clickOnDeleteWorkspacesBtn();
    workspaces.clickOnDeleteButtonInDialogWindow();

    workspaces.waitWorkspaceIsNotPresent(workspaceToDelete.getName());
  }

  private void checkExpectedNodeWorkspaceDisplaying() {
    workspaces.waitWorkspaceIsPresent(expectedNodeItem.getWorkspaceName());
  }

  private void checkExpectedJavaWorkspaceDisplaying() {
    workspaces.waitWorkspaceIsPresent(expectedJavaItem.getWorkspaceName());
  }

  private int getWorkspacesCount() throws Exception {
    return testWorkspaceServiceClient.getAll().size();
  }

  @Test(priority = 1)
  public void checkDocumentionLink() {
    workspaces.waitPageLoading();
    String mainWindow = seleniumWebDriver.getWindowHandle();

    // check documentation link
    workspaces.clickOnDocumentationLink();
    seleniumWebDriverHelper.waitOpenedSomeWin();
    seleniumWebDriverHelper.switchToNextWindow(mainWindow);

    assertEquals(EXPECTED_DOCUMENTATION_PAGE_TITLE, documentationPage.getTitle());

    seleniumWebDriver.close();
    seleniumWebDriver.switchTo().window(mainWindow);
  }
}
