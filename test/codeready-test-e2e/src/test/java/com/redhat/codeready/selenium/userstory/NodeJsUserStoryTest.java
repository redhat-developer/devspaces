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

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.NODE;
import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.ASSISTANT;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.FIND_PROJECT_SYMBOL;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;
import static org.openqa.selenium.Keys.BACK_SPACE;

import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.CodereadyDebuggerPanel;
import com.redhat.codeready.selenium.pageobject.CodereadyEditor;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyFindUsageWidget;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import javax.ws.rs.HttpMethod;
import javax.ws.rs.core.Response;
import org.eclipse.che.api.core.rest.HttpJsonRequestFactory;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.client.TestProjectServiceClient;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.constant.TestTimeoutsConstants;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.utils.WaitUtils;
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
import org.openqa.selenium.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

public class NodeJsUserStoryTest {
  private static final Logger LOG = LoggerFactory.getLogger(NodeJsUserStoryTest.class);
  private final String WORKSPACE = generate("NodeJsUserStoryTest", 4);
  private final String PROJECT = "web-nodejs-simple";
  private final String PATH_TO_MAIN_PACKAGE =
      PROJECT + "/src/main/java/org/jboss/as/quickstarts/kitchensink";
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
  public void createJavaEAPWorkspaceWithProjectFromDashBoard() {
    createWsFromNodeJsStackWithTestProject(PROJECT);
  }

  @Test(priority = 1)
  public void runAndCheckNodeJsApp() throws Exception {
    runAndCheckHelloWorldApp();
  }

  @Test(priority = 2)
  public void checkMainLsFeatures() {
    checkHovering();
    checkCodeValidation();
    checkFindDefinition();
  }

  private void createWsFromNodeJsStackWithTestProject(String example) {
    dashboard.selectWorkspacesItemOnDashboard();
    dashboard.waitToolbarTitleName("Workspaces");
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.typeWorkspaceName(WORKSPACE);
    newWorkspace.selectCodereadyStack(NODE);
    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.addSampleToWorkspace(example);
    newWorkspace.clickOnCreateButtonAndOpenInIDE();
    seleniumWebDriverHelper.switchToIdeFrameAndWaitAvailability();
    projectExplorer.waitItem(example);
    events.clickEventLogBtn();
    events.waitExpectedMessage("Branch 'master' is checked out");
    testWorkspace = testWorkspaceProvider.getWorkspace(WORKSPACE, defaultTestUser);
  }

  private void runAndCheckHelloWorldApp()
      throws InterruptedException, ExecutionException, TimeoutException {
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick(PROJECT + ":run");
    consoles.waitExpectedTextIntoConsole("Example app listening on port 3000!");
    WaitUtils.waitSuccessCondition(
        () -> {
          try {
            return isTestApplicationAvailable(consoles.getPreviewUrl());
          } catch (Exception ex) {
            throw new RuntimeException(ex.getLocalizedMessage(), ex);
          }
        },
        TestTimeoutsConstants.LOAD_PAGE_TIMEOUT_SEC,
        TestTimeoutsConstants.MULTIPLE,
        TimeUnit.SECONDS);
    consoles.waitExpectedTextIntoConsole("Example app listening on port 3000!");
  }

  private boolean isTestApplicationAvailable(String appUrl) throws IOException {
    HttpURLConnection httpURLConnection = (HttpURLConnection) new URL(appUrl).openConnection();
    httpURLConnection.setRequestMethod(HttpMethod.GET);
    return httpURLConnection.getResponseCode() == Response.Status.OK.getStatusCode();
  }

  private void checkCodeValidation() {
    editor.waitActive();
    editor.goToCursorPositionVisible(10, 9);
    editor.typeTextIntoEditor(Keys.SPACE.toString());
    editor.waitMarkerInPosition(ERROR, 10);
    editor.moveToMarker(ERROR, 10);
    editor.waitTextInToolTipPopup("Unexpected token");
    editor.goToCursorPositionVisible(10, 10);
    editor.typeTextIntoEditor(BACK_SPACE.toString());
    editor.waitAllMarkersInvisibility(ERROR);
  }

  private void checkHovering() {
    projectExplorer.quickExpandWithJavaScript();
    projectExplorer.openItemByPath(PROJECT + "/app/app.js");
    editor.moveCursorToText("console");
    editor.waitTextInHoverPopup("Used to print to stdout and stderr.");
  }

  private void checkRenaming() {}

  private void checkFindDefinition() {
    editor.goToPosition(3, 8);
    menu.runCommand(ASSISTANT, FIND_PROJECT_SYMBOL);
    assistantFindPanel.waitForm();
    assistantFindPanel.clickOnInputField();
    assistantFindPanel.typeToInputField("a");
    assistantFindPanel.waitAllNodes("/web-nodejs-simple/node_modules/express/lib/express.js");

    // select item in the find panel by clicking on node
    assistantFindPanel.clickOnActionNodeWithTextContains(
        "/web-nodejs-simple/node_modules/express/lib/express.js");
    assistantFindPanel.waitFormIsClosed();
    editor.waitTextIntoEditor("function createApplication()");
    editor.waitTabIsPresent("express.js");
    editor.waitCursorPosition(48, 2);
  }
}
