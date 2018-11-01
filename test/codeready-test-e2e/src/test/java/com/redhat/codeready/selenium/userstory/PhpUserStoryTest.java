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

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.PHP;
import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR_OVERVIEW;
import static org.openqa.selenium.Keys.CONTROL;
import static org.openqa.selenium.Keys.SPACE;
import static org.openqa.selenium.Keys.chord;

import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.CodereadyDebuggerPanel;
import com.redhat.codeready.selenium.pageobject.CodereadyEditor;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyFindUsageWidget;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import org.eclipse.che.api.core.rest.HttpJsonRequestFactory;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.client.TestProjectServiceClient;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.core.workspace.TestWorkspaceProvider;
import org.eclipse.che.selenium.pageobject.AssistantFindPanel;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Events;
import org.eclipse.che.selenium.pageobject.Menu;
import org.eclipse.che.selenium.pageobject.NotificationsPopupPanel;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.Wizard;
import org.eclipse.che.selenium.pageobject.dashboard.AddOrImportForm;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceDetails;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceOverview;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.eclipse.che.selenium.pageobject.debug.JavaDebugConfig;
import org.eclipse.che.selenium.pageobject.intelligent.CommandsPalette;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

public class PhpUserStoryTest {
  private static final Logger LOG = LoggerFactory.getLogger(NodeJsUserStoryTest.class);
  private final String WORKSPACE = generate(PhpUserStoryTest.class.getSimpleName(), 4);
  private final String PROJECT_NAME = "web-php-simple";

  @Inject private Dashboard dashboard;
  @Inject private WorkspaceDetails workspaceDetails;
  @Inject private Workspaces workspaces;
  @Inject private WorkspaceOverview workspaceOverview;
  @Inject private CodereadyNewWorkspace newWorkspace;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private TestWorkspaceProvider testWorkspaceProvider;
  @Inject private SeleniumWebDriverHelper seleniumWebDriverHelper;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private TestWorkspaceServiceClient workspaceServiceClient;
  @Inject private AddOrImportForm addOrImportForm;
  @Inject private CommandsPalette commandsPalette;
  @Inject private Wizard wizard;
  @Inject private Consoles consoles;
  @Inject private CodereadyEditor editor;
  @Inject private HttpJsonRequestFactory requestFactory;
  @Inject private Menu menu;
  @Inject private CodereadyDebuggerPanel debugPanel;
  @Inject private JavaDebugConfig debugConfig;
  @Inject private Events events;
  @Inject private NotificationsPopupPanel notifications;
  @Inject private CodereadyFindUsageWidget findUsages;
  @Inject private TestProjectServiceClient projectServiceClient;
  @Inject private SeleniumWebDriver seleniumWebDriver;
  @Inject private AssistantFindPanel assistantFindPanel;
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
  public void shouldCreatePhpStackWithProject() {
    dashboard.selectWorkspacesItemOnDashboard();
    dashboard.waitToolbarTitleName("Workspaces");
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.typeWorkspaceName(WORKSPACE);
    newWorkspace.selectCodereadyStack(PHP);
    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.addSampleToWorkspace(PROJECT_NAME);
    newWorkspace.clickOnCreateButtonAndOpenInIDE();
    seleniumWebDriverHelper.switchToIdeFrameAndWaitAvailability();
    projectExplorer.waitItem(PROJECT_NAME);
    events.clickEventLogBtn();
    events.waitExpectedMessage("Branch 'master' is checked out");
    testWorkspace = testWorkspaceProvider.getWorkspace(WORKSPACE, defaultTestUser);
  }

  @Test(priority = 1)
  public void checkBuildingAndRunning() {}

  @Test(priority = 2)
  public void mainPhpLsFeaturesShouldWork() {
    final String checkedFileName = "index.php";

    projectExplorer.waitItem(PROJECT_NAME);
    projectExplorer.expandPathInProjectExplorerAndOpenFile(PROJECT_NAME, checkedFileName);
    editor.waitTabIsPresent(checkedFileName);
    editor.waitActive();

    checkCodeValidation();
    checkAutocompletion();
    checkCommenting();
  }

  private void checkCommenting() {}

  private void checkAutocompletion() {
    editor.waitActive();
    editor.goToCursorPositionVisible(7, 2);
    editor.typeTextIntoEditor("\nsay");
    editor.waitTextIntoEditor("}\nsay");
    editor.typeTextIntoEditor(chord(CONTROL, SPACE));
    editor.waitTextIntoEditor("}\nsayHello");
  }

  private void checkCodeValidation() {
    final String expectedFixedCode = "echo \"Hello World!\";";
    final String codeForTyping = "\nfunction sayHello($name) {\n" + "return \"Hello, $name\";";
    final String codeForChecking =
        "function sayHello($name) {\n" + "    return \"Hello, $name\";\n" + "}";

    editor.setCursorToLine(4);
    editor.typeTextIntoEditor(codeForTyping);
    editor.waitTextIntoEditor(codeForChecking);

    editor.clickOnMarker(ERROR_OVERVIEW, 15);
    editor.waitTextInToolTipPopup("';' expected.");

    editor.goToCursorPositionVisible(3, 20);
    editor.typeTextIntoEditor(";");
    editor.waitTextIntoEditor(expectedFixedCode);
    editor.waitAllMarkersInvisibility(ERROR_OVERVIEW);
  }
}
