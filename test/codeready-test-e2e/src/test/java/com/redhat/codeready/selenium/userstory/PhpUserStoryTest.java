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
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.RUN_GOAL;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.LOADER_TIMEOUT_SEC;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR_OVERVIEW;
import static org.openqa.selenium.Keys.ARROW_DOWN;
import static org.openqa.selenium.Keys.LEFT_CONTROL;
import static org.openqa.selenium.Keys.LEFT_SHIFT;
import static org.openqa.selenium.Keys.SPACE;

import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.CodereadyEditor;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import java.util.concurrent.atomic.AtomicReference;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.core.workspace.TestWorkspaceProvider;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Events;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.dashboard.AddOrImportForm;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.openqa.selenium.By;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

public class PhpUserStoryTest {
  private static final String WORKSPACE = generate(PhpUserStoryTest.class.getSimpleName(), 4);
  private static final String PROJECT_NAME = "web-php-simple";
  private static final String START_APP_COMMAND_NAME = "start httpd";
  private static final String EXPECTED_APPLICATION_BODY_TEXT = "Hello World!";
  private static final String EXPECTED_FIXED_CODE = "echo \"Hello World!\";";
  private static final String CODE_FOR_TYPING =
      "\nfunction sayHello($name) {\n" + "return \"Hello, $name\";";
  //  private static final String CODE_FOR_CHECKING =
  //      "function sayHello($name) {\n" + "    return \"Hello, $name\";\n" + "}";

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

  @Inject private Dashboard dashboard;
  @Inject private Workspaces workspaces;
  @Inject private CodereadyNewWorkspace newWorkspace;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private TestWorkspaceProvider testWorkspaceProvider;
  @Inject private SeleniumWebDriverHelper seleniumWebDriverHelper;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private TestWorkspaceServiceClient workspaceServiceClient;
  @Inject private AddOrImportForm addOrImportForm;
  @Inject private Consoles consoles;
  @Inject private CodereadyEditor editor;
  @Inject private Events events;
  @Inject private SeleniumWebDriver seleniumWebDriver;
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
    // go to "New Workspace" page
    dashboard.selectWorkspacesItemOnDashboard();
    dashboard.waitToolbarTitleName("Workspaces");
    workspaces.clickOnAddWorkspaceBtn();

    // set configuration and run workspace
    newWorkspace.typeWorkspaceName(WORKSPACE);
    newWorkspace.selectCodereadyStack(PHP);
    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.addSampleToWorkspace(PROJECT_NAME);
    newWorkspace.clickOnCreateButtonAndOpenInIDE();

    // check workspace creation and readiness
    seleniumWebDriverHelper.switchToIdeFrameAndWaitAvailability();
    projectExplorer.waitItem(PROJECT_NAME);
    projectExplorer.waitAndSelectItem(PROJECT_NAME);
    events.clickEventLogBtn();
    events.waitExpectedMessage("Branch 'master' is checked out");
    testWorkspace = testWorkspaceProvider.getWorkspace(WORKSPACE, defaultTestUser);
  }

  @Test(priority = 1)
  public void checkBuildingAndRunning() {
    // waits application source readiness and run
    projectExplorer.waitItem(PROJECT_NAME);
    projectExplorer.invokeCommandWithContextMenu(RUN_GOAL, PROJECT_NAME, START_APP_COMMAND_NAME);

    waitApplicationAvailability();
  }

  @Test(priority = 2)
  public void mainPhpLsFeaturesShouldWork() {
    final String checkedFileName = "index.php";

    // prepare file for checks
    projectExplorer.waitItem(PROJECT_NAME);
    projectExplorer.expandPathInProjectExplorerAndOpenFile(PROJECT_NAME, checkedFileName);
    editor.waitTabIsPresent(checkedFileName);
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
          consoles.waitPreviewUrlIsPresent();
          consoles.clickOnPreviewUrl();
          seleniumWebDriverHelper.switchToNextWindow(parentWindow);

          currentText.set(getBodyText());

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

    seleniumWebDriverHelper
        .getAction()
        .keyDown(LEFT_CONTROL)
        .sendKeys("/")
        .keyUp(LEFT_CONTROL)
        .perform();
  }

  private void checkAutocompletion() {
    // prepare file
    editor.waitActive();
    editor.goToCursorPositionVisible(7, 2);
    editor.typeTextIntoEditor("\nsay");
    editor.waitTextIntoEditor("}\nsay");

    // check autocompletion
    performAutocomplete();
    editor.waitTextIntoEditor("}\nsayHello");
  }

  private void performAutocomplete() {
    seleniumWebDriverHelper
        .getAction()
        .keyDown(LEFT_CONTROL)
        .sendKeys(SPACE)
        .keyUp(LEFT_CONTROL)
        .perform();
  }

  private void checkCodeValidation() {
    // prepare file
    editor.setCursorToLine(4);
    editor.typeTextIntoEditor(CODE_FOR_TYPING);
    editor.waitTextIntoEditor(EXPECTED_REGULAR_TEXT);

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
