/*
* Copyright (c) 2019 Red Hat, Inc.

* All rights reserved. This program and the accompanying materials
* are made available under the terms of the Eclipse Public License v2.0
* which accompanies this distribution, and is available at
* http://www.eclipse.org/legal/epl-2.0
*
* Contributors:
*   Red Hat, Inc. - initial API and implementation
*/
package com.redhat.codeready.selenium.userstory;

import static java.util.Arrays.stream;
import static org.eclipse.che.selenium.core.constant.TestBuildConstants.BUILD_SUCCESS;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.BUILD_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.DEBUG_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.RUN_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.ASSISTANT;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.FIND_USAGES;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.BUILD_GOAL;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.DEBUG_GOAL;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.RUN_GOAL;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.APPLICATION_START_TIMEOUT_SEC;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.LOADER_TIMEOUT_SEC;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.UPDATING_PROJECT_TIMEOUT_SEC;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;

import com.google.common.collect.ImmutableList;
import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyFindUsageWidget;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import java.util.Arrays;
import java.util.List;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.pageobject.CodenvyEditor;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Events;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.MavenPluginStatusBar;
import org.eclipse.che.selenium.pageobject.Menu;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.intelligent.CommandsPalette;
import org.openqa.selenium.By;
import org.testng.annotations.Test;

/** @author Aleksandr Shmaraiev */
public class VertxUserStoryTest extends AbstractUserStoryTest {
  private static final String VERTX_PROJECT_NAME = "vertx-http-booster";
  private static final String PATH_TO_MAIN_PACKAGE =
      VERTX_PROJECT_NAME + "/src/main/java/io.openshift.booster";
  private static final String JAVA_FILE_NAME = "HttpApplication";

  private static final String[] REPORT_DEPENDENCY_ANALYSIS = {
    "Report for /projects/vertx-http-booster/pom.xml",
    "1) # of application dependencies : 2",
    "2) Dependencies with Licenses : ",
    "3) Suggest adding these dependencies to your application stack:",
    "4) No usage outlier application depedencies found",
    "5) No alternative  application depedencies suggested"
  };

  @Inject private Ide ide;
  @Inject private CommandsPalette commandsPalette;
  @Inject private Consoles consoles;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private MavenPluginStatusBar mavenPluginStatusBar;
  @Inject private CodenvyEditor editor;
  @Inject private Events events;
  @Inject private Menu menu;
  @Inject private CodereadyFindUsageWidget findUsages;
  @Inject private SeleniumWebDriver seleniumWebDriver;
  @Inject private SeleniumWebDriverHelper seleniumWebDriverHelper;

  @Override
  protected List<String> getProjects() {
    return ImmutableList.of(VERTX_PROJECT_NAME);
  }

  @Override
  protected CodereadyNewWorkspace.CodereadyStacks getStackName() {
    return CodereadyNewWorkspace.CodereadyStacks.VERTX;
  }

  @Test
  @Override
  public void createWorkspaceFromDashboard() throws Exception {
    super.createWorkspaceFromDashboard();

    // wait expected message in the progress info bar
    // the execution takes a lot of time on a local machine, so need a big timeout
    mavenPluginStatusBar.waitInfoPanelIsNotEmpty();
    mavenPluginStatusBar.waitClosingInfoPanel(APPLICATION_START_TIMEOUT_SEC);

    // check the project is initialized
    projectExplorer.waitProjectInitialization(VERTX_PROJECT_NAME);
  }

  @Test(priority = 2)
  public void checkReportDependencyAnalysisCommand() {
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick("dependency_analysis");
    consoles.waitExpectedTextIntoConsole(BUILD_SUCCESS);

    stream(REPORT_DEPENDENCY_ANALYSIS)
        .forEach(partOfContent -> consoles.waitExpectedTextIntoConsole(partOfContent));
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
    // the execution take a lot of time on a local machine, so need a big timeout
    mavenPluginStatusBar.waitClosingInfoPanel(UPDATING_PROJECT_TIMEOUT_SEC);

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
    editor.waitTextIntoEditor("router.set();");
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
    editor.goToPosition(19, 12);
    menu.runCommand(ASSISTANT, FIND_USAGES);
    findUsages.waitExpectedOccurences(3);
  }

  private void checkApplicationPage(By webElement) {
    consoles.waitPreviewUrlIsPresent();
    consoles.waitPreviewUrlIsResponsive(10);
    consoles.clickOnPreviewUrl();

    seleniumWebDriverHelper.switchToNextWindow(getIdeWindow());

    seleniumWebDriver.navigate().refresh();
    seleniumWebDriverHelper.waitVisibility(webElement, LOADER_TIMEOUT_SEC);

    seleniumWebDriver.close();
    seleniumWebDriver.switchTo().window(getIdeWindow());
    seleniumWebDriverHelper.switchToIdeFrameAndWaitAvailability();
  }
}
