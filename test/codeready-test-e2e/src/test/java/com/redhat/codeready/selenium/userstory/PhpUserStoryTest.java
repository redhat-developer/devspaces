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

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.PHP;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Run.DEBUG;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Run.EDIT_DEBUG_CONFIGURATION;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Run.RUN_MENU;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.DEBUG_GOAL;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.RUN_GOAL;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.LOADER_TIMEOUT_SEC;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR_OVERVIEW;
import static org.openqa.selenium.Keys.ARROW_DOWN;
import static org.openqa.selenium.Keys.LEFT_CONTROL;
import static org.openqa.selenium.Keys.LEFT_SHIFT;

import com.google.common.collect.ImmutableList;
import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.CodereadyEditor;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import java.net.URI;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.client.TestProjectServiceClient;
import org.eclipse.che.selenium.core.project.ProjectTemplates;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Events;
import org.eclipse.che.selenium.pageobject.Menu;
import org.eclipse.che.selenium.pageobject.NotificationsPopupPanel;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.debug.DebugPanel;
import org.eclipse.che.selenium.pageobject.debug.PhpDebugConfig;
import org.openqa.selenium.By;
import org.testng.annotations.Test;

public class PhpUserStoryTest extends AbstractUserStoryTest {
  private static final String PROJECT_NAME = "web-php-simple";
  private static final String DEBUG_PROJECT_NAME = "debug-php";
  private static final String START_APP_COMMAND_NAME = "start httpd";
  private static final String EXPECTED_APPLICATION_BODY_TEXT = "Hello World!";
  private static final String EXPECTED_FIXED_CODE = "echo \"Hello World!\";";
  private static final String INDEX_FILE = "index.php";
  private static final String LIB_FILE = "lib.php";
  private static final String PATH_TO_INDEX_PHP = DEBUG_PROJECT_NAME + "/" + INDEX_FILE;
  private static final String DEBUG_PHP_SCRIPT_COMMAND_NAME = "debug php script";

  private static final String CODE_FOR_TYPING =
      "\nfunction sayHello($name) {\n" + "return \"Hello, $name\";";

  private static final String EXPECTED_TYPED_TEXT =
      "<?php\n"
          + "\n"
          + "echo \"Hello World!\"\n"
          + "\n"
          + "function sayHello($name) {\n"
          + "    return \"Hello, $name\";\n"
          + "}\n"
          + "?>";

  private static final String EXPECTED_REGULAR_TEXT =
      "<?php\n"
          + "\n"
          + "echo \"Hello World!\";\n"
          + "\n"
          + "function sayHello($name) {\n"
          + "    return \"Hello, $name\";\n"
          + "}\n"
          + "sayHello\n"
          + "?>";

  private static final String EXPECTED_BY_CONTROL_SHIFT_COMMENTED_TEXT =
      "echo \"Hello World!\";\n"
          + "/*\n"
          + "function sayHello($name) {\n"
          + "    return \"Hello, $name\";\n"
          + "}\n"
          + "*/sayHello";

  private static final String EXPECTED_BY_CONTROL_COMMENTED_TEXT =
      "//\n"
          + "//function sayHello($name) {\n"
          + "//    return \"Hello, $name\";\n"
          + "//}\n"
          + "sayHello";

  @Inject private SeleniumWebDriverHelper seleniumWebDriverHelper;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private TestProjectServiceClient testProjectServiceClient;
  @Inject private Consoles consoles;
  @Inject private CodereadyEditor editor;
  @Inject private Events events;
  @Inject private SeleniumWebDriver seleniumWebDriver;
  @Inject private Menu menu;
  @Inject private DebugPanel debugPanel;
  @Inject private PhpDebugConfig debugConfig;
  @Inject private NotificationsPopupPanel notificationPopup;

  @Override
  protected CodereadyNewWorkspace.CodereadyStacks getStackName() {
    return PHP;
  }

  @Override
  protected List<String> getProjects() {
    return ImmutableList.of(PROJECT_NAME);
  }

  @Override
  @Test
  public void createWorkspaceFromDashboard() throws Exception {
    super.createWorkspaceFromDashboard();

    projectExplorer.waitItem(PROJECT_NAME);
    projectExplorer.waitAndSelectItem(PROJECT_NAME);
    events.clickEventLogBtn();
    events.waitExpectedMessage("Branch 'master' is checked out");
  }

  @Test(priority = 1)
  public void checkBuildingAndRunning() {
    // waits application source readiness and run
    projectExplorer.waitItem(PROJECT_NAME);
    projectExplorer.invokeCommandWithContextMenu(RUN_GOAL, PROJECT_NAME, START_APP_COMMAND_NAME);

    waitApplicationAvailability();
  }

  @Test(priority = 2)
  public void checkDebugMode() throws Exception {
    final URI resource =
        getClass().getResource("/projects/plugins/DebuggerPlugin/php-tests").toURI();
    final Path resourcePath = Paths.get(resource);

    // create test project
    testProjectServiceClient.importProject(
        testWorkspace.getId(), resourcePath, DEBUG_PROJECT_NAME, ProjectTemplates.PHP);

    // create debug configuration
    projectExplorer.waitAndSelectItem(DEBUG_PROJECT_NAME);
    projectExplorer.waitItemIsSelected(DEBUG_PROJECT_NAME);
    menu.runCommand(RUN_MENU, EDIT_DEBUG_CONFIGURATION);
    debugConfig.createConfig(DEBUG_PROJECT_NAME);

    // run remote debugger
    menu.runCommand(RUN_MENU, DEBUG, DEBUG + "/" + DEBUG_PROJECT_NAME);
    notificationPopup.waitExpectedMessageOnProgressPanelAndClose("Remote debugger connected");

    // set breakpoint
    projectExplorer.expandPathInProjectExplorerAndOpenFile(DEBUG_PROJECT_NAME, LIB_FILE);
    editor.waitTabIsPresent(LIB_FILE);
    editor.waitTabSelection(0, LIB_FILE);
    editor.waitActive();
    editor.setBreakpoint(14);
    editor.closeAllTabs();
    editor.waitTabIsNotPresent(LIB_FILE);

    // run script debugging
    projectExplorer.openItemByPath(PATH_TO_INDEX_PHP);
    editor.waitTabIsPresent(INDEX_FILE);
    editor.waitTabSelection(0, INDEX_FILE);
    projectExplorer.invokeCommandWithContextMenu(
        DEBUG_GOAL, DEBUG_PROJECT_NAME, DEBUG_PHP_SCRIPT_COMMAND_NAME);

    // check starting debug state
    debugPanel.openDebugPanel();
    debugPanel.waitDebugHighlightedText("<?php include 'lib.php';?>");
    debugPanel.waitTextInVariablesPanel("$_GET=array [0]");

    // check stopping on breakpoint
    debugPanel.clickOnButton(DebugPanel.DebuggerActionButtons.RESUME_BTN_ID);
    editor.waitTabFileWithSavedStatus(LIB_FILE);
    editor.waitActiveBreakpoint(14);
    debugPanel.waitDebugHighlightedText("return \"Hello, $name\"");
    debugPanel.waitTextInVariablesPanel("$name=\"man\"");

    // check "Step Out" button
    debugPanel.clickOnButton(DebugPanel.DebuggerActionButtons.STEP_OUT);
    editor.waitTabFileWithSavedStatus(INDEX_FILE);
    debugPanel.waitDebugHighlightedText("echo sayHello(\"man\");");
    debugPanel.waitTextInVariablesPanel("$_GET=array [0]");

    // restore starting state
    editor.closeAllTabs();
    editor.waitTabIsNotPresent(INDEX_FILE);
  }

  @Test(priority = 3)
  public void checkPhpLsFeatures() {
    // prepare file for checks
    projectExplorer.waitItem(PROJECT_NAME);
    projectExplorer.expandPathInProjectExplorerAndOpenFile(PROJECT_NAME, INDEX_FILE);
    editor.waitTabIsPresent(INDEX_FILE);
    editor.waitActive();

    checkCodeValidation();
    checkAutocompletion();
    checkCommenting();
  }

  private void checkCommenting() {
    editor.waitActive();
    editor.setCursorToLine(4);

    // commenting by "Ctrl" + "Shift" + "/"
    performCommentingByControlShift();
    editor.waitTextIntoEditor(EXPECTED_BY_CONTROL_SHIFT_COMMENTED_TEXT);

    performUndoCommand();
    editor.waitTextIntoEditor(EXPECTED_REGULAR_TEXT);

    // commenting by "Ctrl" + "/"
    editor.setCursorToLine(4);
    performCommentingByControl();
    editor.waitTextIntoEditor(EXPECTED_BY_CONTROL_COMMENTED_TEXT);

    performUndoCommand();
    editor.waitTextIntoEditor(EXPECTED_REGULAR_TEXT);
  }

  private void performUndoCommand() {
    seleniumWebDriverHelper
        .getAction()
        .keyDown(LEFT_CONTROL)
        .sendKeys("z")
        .keyUp(LEFT_CONTROL)
        .perform();
  }

  private void waitApplicationAvailability() {
    final String parentWindow = seleniumWebDriver.getWindowHandle();
    final AtomicReference<String> currentText = new AtomicReference<>();

    seleniumWebDriverHelper.waitSuccessCondition(
        driver -> {
          // open app window by preview URL in terminal
          consoles.waitPreviewUrlIsPresent();
          consoles.clickOnPreviewUrl();
          seleniumWebDriverHelper.switchToNextWindow(parentWindow);

          currentText.set(getBodyText());

          // close app window and switch to parent window
          seleniumWebDriver.close();
          seleniumWebDriver.switchTo().window(parentWindow);
          seleniumWebDriverHelper.switchToIdeFrameAndWaitAvailability();

          return currentText.get().contains(EXPECTED_APPLICATION_BODY_TEXT);
        },
        LOADER_TIMEOUT_SEC);
  }

  private String getBodyText() {
    return seleniumWebDriverHelper.waitVisibilityAndGetText(By.tagName("body"));
  }

  private void performCommentingByControlShift() {
    performTextSelecting();

    pressControlShiftCommentingCombination();
  }

  private void performTextSelecting() {
    seleniumWebDriverHelper
        .getAction()
        .keyDown(LEFT_SHIFT)
        .sendKeys(ARROW_DOWN, ARROW_DOWN, ARROW_DOWN, ARROW_DOWN)
        .keyUp(LEFT_SHIFT)
        .perform();
  }

  private void pressControlShiftCommentingCombination() {
    seleniumWebDriverHelper
        .getAction()
        .keyDown(LEFT_CONTROL)
        .keyDown(LEFT_SHIFT)
        .sendKeys("/")
        .keyUp(LEFT_CONTROL)
        .keyUp(LEFT_SHIFT)
        .perform();
  }

  private void performCommentingByControl() {
    performTextSelecting();

    editor.launchCommentCodeFeature();
  }

  private void checkAutocompletion() {
    // prepare file
    editor.waitActive();
    editor.goToCursorPositionVisible(7, 2);
    editor.typeTextIntoEditor("\nsay");
    editor.waitTextIntoEditor("}\nsay");

    // check autocompletion
    editor.launchAutocomplete();
    editor.waitTextIntoEditor("}\nsayHello");
  }

  private void checkCodeValidation() {
    // prepare file
    editor.setCursorToLine(4);
    editor.typeTextIntoEditor(CODE_FOR_TYPING);
    editor.waitTextIntoEditor(EXPECTED_TYPED_TEXT);

    // check error marker availability and error hint
    editor.clickOnMarker(ERROR_OVERVIEW, 15);
    editor.waitTextInToolTipPopup("';' expected.");

    // validation of error fixing
    editor.goToCursorPositionVisible(3, 20);
    editor.typeTextIntoEditor(";");
    editor.waitTextIntoEditor(EXPECTED_FIXED_CODE);
    editor.waitAllMarkersInvisibility(ERROR_OVERVIEW);
  }
}
