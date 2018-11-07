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

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.VERTX;
import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.eclipse.che.selenium.core.constant.TestBuildConstants.BUILD_SUCCESS;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.BUILD_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.DEBUG_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.RUN_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.ASSISTANT;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.FIND_USAGES;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.BUILD_GOAL;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.DEBUG_GOAL;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.RUN_GOAL;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.LOADER_TIMEOUT_SEC;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;

import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyFindUsageWidget;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import java.util.Arrays;
import java.util.List;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.core.workspace.TestWorkspaceProvider;
import org.eclipse.che.selenium.pageobject.CodenvyEditor;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Events;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.MavenPluginStatusBar;
import org.eclipse.che.selenium.pageobject.Menu;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.dashboard.AddOrImportForm;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.openqa.selenium.By;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/** @author Aleksandr Shmaraiev */
public class VertxUserStoryTest {

  private static final String WORKSPACE_NAME = generate("VertxUserStoryWs", 4);
  private static final String VERTX_PROJECT_NAME = "vertx-http-booster";
  private static final String PATH_TO_MAIN_PACKAGE =
      VERTX_PROJECT_NAME + "/src/main/java/io.openshift.booster";
  private static final String JAVA_FILE_NAME = "HttpApplication";

  // it is used to read workspace logs on test failure
  @Inject private Ide ide;
  @Inject private Workspaces workspaces;
  @Inject private Consoles consoles;
  @Inject private CodereadyNewWorkspace newWorkspace;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private Dashboard dashboard;
  @Inject private AddOrImportForm addOrImportForm;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private MavenPluginStatusBar mavenPluginStatusBar;
  @Inject private CodenvyEditor editor;
  @Inject private Events events;
  @Inject private Menu menu;
  @Inject private CodereadyFindUsageWidget findUsages;
  @Inject private SeleniumWebDriver seleniumWebDriver;
  @Inject private SeleniumWebDriverHelper seleniumWebDriverHelper;
  @Inject private TestWorkspaceServiceClient workspaceServiceClient;
  @Inject private TestWorkspaceProvider testWorkspaceProvider;

  // it is used to read workspace logs on test failure
  private TestWorkspace testWorkspace;
  private String currentWindow;

  @BeforeClass
  public void setUp() {
    dashboard.open();
  }

  @AfterClass
  public void tearDown() throws Exception {
    workspaceServiceClient.delete(WORKSPACE_NAME, defaultTestUser.getName());
  }

  @Test
  public void checkWorkspaceCreationFromVertxStack() {
    // store info about created workspace to make SeleniumTestHandler.captureTestWorkspaceLogs()
    // possible to read logs in case of test failure
    // select the vert.x ready stack to create the workspace
    dashboard.selectWorkspacesItemOnDashboard();
    dashboard.waitToolbarTitleName("Workspaces");
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.typeWorkspaceName(WORKSPACE_NAME);
    newWorkspace.selectCodereadyStack(VERTX);

    // create the workspace with a template project
    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.addSampleToWorkspace(VERTX_PROJECT_NAME);
    newWorkspace.clickOnCreateButtonAndOpenInIDE();

    // switch to the IDE
    currentWindow = ide.switchToIdeAndWaitWorkspaceIsReadyToUse();
    testWorkspace = testWorkspaceProvider.getWorkspace(WORKSPACE_NAME, defaultTestUser);

    // wait expected message in the progress info bar
    mavenPluginStatusBar.waitExpectedTextInInfoPanel("Refreshing Maven model");
    mavenPluginStatusBar.waitClosingInfoPanel();

    // check the project is initialized
    projectExplorer.waitProjectInitialization(VERTX_PROJECT_NAME);
  }

  @Test(priority = 1)
  public void checkLanguageServerInitialized() {
    // check the message in the 'Event' panel
    events.clickEventLogBtn();
    events.waitExpectedMessage("Branch 'master' is checked out");

    // check JDT language server is initialized
    consoles.clickOnProcessesButton();
    consoles.selectProcessByTabName("dev-machine");
    consoles.waitJDTLSProjectResolveFinishedMessage(VERTX_PROJECT_NAME);

    // wait expected message in the progress info bar
    mavenPluginStatusBar.waitExpectedTextInInfoPanel("Download sources and javadoc:");
    mavenPluginStatusBar.waitClosingInfoPanel();

    projectExplorer.expandPathInProjectExplorerAndOpenFile(
        PATH_TO_MAIN_PACKAGE, JAVA_FILE_NAME + ".java");
    editor.waitTabIsPresent(JAVA_FILE_NAME);
  }

  @Test(priority = 1)
  public void checkVertxHttpBoosterProjectCommands() {
    By textOnPreviewPage = By.id("_http_booster");

    // build and run web application
    consoles.executeCommandFromProjectExplorer(
        VERTX_PROJECT_NAME, BUILD_GOAL, BUILD_COMMAND, BUILD_SUCCESS);
    consoles.executeCommandFromProjectExplorer(
        VERTX_PROJECT_NAME, RUN_GOAL, RUN_COMMAND, "[INFO] INFO: Succeeded in deploying verticle");

    // refresh application web page and check visibility of web element on opened page
    checkApplicationPage(textOnPreviewPage);

    consoles.closeProcessTabWithAskDialog(RUN_COMMAND);

    consoles.executeCommandFromProcessesArea(
        "dev-machine",
        DEBUG_GOAL,
        DEBUG_COMMAND,
        "[INFO] Listening for transport dt_socket at address: 5005");
    consoles.closeProcessTabWithAskDialog(DEBUG_COMMAND);
  }

  @Test(priority = 2)
  public void checkAutoCompletionFeature() {
    List<String> expectedContentInAutocompleteContainer =
        Arrays.asList("response : JsonObject", "jsonObject : JsonObject", "object : JsonObject");

    editor.selectTabByName(JAVA_FILE_NAME);
    editor.goToPosition(45, 16);
    editor.launchAutocomplete();
    editor.waitProposalsIntoAutocompleteContainer(expectedContentInAutocompleteContainer);
    editor.closeAutocomplete();
  }

  @Test(priority = 2)
  public void checkQuickFixFeature() {
    String expectedTextAfterQuickFix = "router.get()";

    // type wrong expression
    editor.selectTabByName(JAVA_FILE_NAME);
    editor.setCursorToLine(20);
    editor.typeTextIntoEditor("    router.set();");
    editor.waitMarkerInPosition(ERROR, 20);

    // invoke the code assist panel
    editor.goToPosition(20, 15);
    editor.launchPropositionAssistPanel();
    editor.waitTextIntoFixErrorProposition("Change to 'get(..)'");
    editor.waitTextIntoFixErrorProposition("Add cast to 'router'");

    // use the proposal from the code assist panel
    editor.selectFirstItemIntoFixErrorPropByDoubleClick();
    editor.waitTextIntoEditor(expectedTextAfterQuickFix);
    editor.waitMarkerInvisibility(ERROR, 20);
  }

  @Test(priority = 2)
  public void checkFindUsagesFeature() {
    editor.selectTabByName(JAVA_FILE_NAME);
    editor.goToPosition(19, 5);
    menu.runCommand(ASSISTANT, FIND_USAGES);
    findUsages.waitExpectedOccurences(55);
  }

  private void checkApplicationPage(By webElement) {
    consoles.waitPreviewUrlIsPresent();
    consoles.waitPreviewUrlIsResponsive(10);
    consoles.clickOnPreviewUrl();

    seleniumWebDriverHelper.switchToNextWindow(currentWindow);

    seleniumWebDriver.navigate().refresh();
    seleniumWebDriverHelper.waitVisibility(webElement, LOADER_TIMEOUT_SEC);

    seleniumWebDriver.close();
    seleniumWebDriver.switchTo().window(currentWindow);
    seleniumWebDriverHelper.switchToIdeFrameAndWaitAvailability();
  }
}
