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
package com.redhat.codeready.selenium.intelligencecommand;

import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Workspace.CREATE_PROJECT;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Workspace.WORKSPACE;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.ELEMENT_TIMEOUT_SEC;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.LOAD_PAGE_TIMEOUT_SEC;

import com.google.inject.Inject;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.Menu;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.Wizard;
import org.eclipse.che.selenium.pageobject.intelligent.CommandsToolbar;
import org.openqa.selenium.By;
import org.openqa.selenium.StaleElementReferenceException;
import org.openqa.selenium.support.ui.ExpectedCondition;
import org.openqa.selenium.support.ui.WebDriverWait;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/** @author Musienko Maxim */
public class CheckIntelligenceCommandFromToolbarTest {
  private static final String PROJECT_NAME = generate("project", 2);
  private String currentWindow;

  @Inject private TestWorkspace testWorkspace;
  @Inject private Ide ide;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private Consoles consoles;
  @Inject private Menu menu;
  @Inject private Wizard wizard;
  @Inject private CommandsToolbar commandsToolbar;
  @Inject private SeleniumWebDriver seleniumWebDriver;
  @Inject private SeleniumWebDriverHelper seleniumWebDriverHelper;

  @BeforeClass
  public void setUp() throws Exception {
    ide.open(testWorkspace);
    projectExplorer.waitProjectExplorer();
    currentWindow = seleniumWebDriver.getWindowHandle();
  }

  @Test
  public void launchClonedWepAppTest() {
    menu.runCommand(WORKSPACE, CREATE_PROJECT);
    wizard.selectProjectAndCreate("kitchensink-example", PROJECT_NAME);
    wizard.waitCreateProjectWizardFormIsClosed();
    projectExplorer.waitItem(PROJECT_NAME);
    commandsToolbar.clickWithHoldAndLaunchCommandFromList(
        PROJECT_NAME + ": build and run in debug");
    consoles.waitExpectedTextIntoConsole("started in");

    waitOnAvailablePreviewPage(currentWindow, "Welcome to JBoss AS 7!");
    consoles.waitExpectedTextIntoConsole("started in");
    seleniumWebDriver.navigate().refresh();
    projectExplorer.waitProjectExplorer();
    consoles.selectProcessByTabName(PROJECT_NAME + ": build and run in debug");
    consoles.waitExpectedTextIntoConsole("started in");
    checkTestAppByPreviewUrlAndReturnToIde(currentWindow, "Welcome to JBoss AS 7!");
  }

  @Test(priority = 1)
  public void checkButtonsOnToolbarOnOpenshift() {
    checkButtonsOnToolbar("Application is not available");
  }

  private void checkButtonsOnToolbar(String expectedText) {
    projectExplorer.waitProjectExplorer();
    projectExplorer.waitItem(PROJECT_NAME);
    commandsToolbar.clickExecStopBtn();

    checkTestAppByPreviewUrlAndReturnToIde(currentWindow, expectedText);
    commandsToolbar.clickExecRerunBtn();
    consoles.waitExpectedTextIntoConsole("started in");
    consoles.clickOnPreviewUrl();

    waitOnAvailablePreviewPage(currentWindow, "Welcome to JBoss AS 7!");
    commandsToolbar.waitTimerValuePattern("\\d\\d:\\d\\d");
    commandsToolbar.waitNumOfProcessCounter(3);

    checkTestAppByPreviewButtonAndReturnToIde(currentWindow, "Welcome to JBoss AS 7!");
    commandsToolbar.clickExecStopBtn();
  }

  private void checkTestAppByPreviewUrlAndReturnToIde(String currentWindow, String expectedText) {
    new WebDriverWait(seleniumWebDriver, LOAD_PAGE_TIMEOUT_SEC)
        .until(
            (ExpectedCondition<Boolean>)
                driver ->
                    clickOnPreviewUrlAndCheckTextIsPresentInPageBody(currentWindow, expectedText));
  }

  private void checkTestAppByPreviewButtonAndReturnToIde(
      String currentWindow, String expectedText) {
    new WebDriverWait(seleniumWebDriver, LOAD_PAGE_TIMEOUT_SEC)
        .until(
            (ExpectedCondition<Boolean>)
                driver ->
                    clickOnPreviewButtonAndCheckTextIsPresentInPageBody(
                        currentWindow, expectedText));
  }

  private boolean clickOnPreviewUrlAndCheckTextIsPresentInPageBody(
      String currentWindow, String expectedText) {
    consoles.clickOnPreviewUrl();
    return switchToOpenedWindowAndCheckTextIsPresent(currentWindow, expectedText);
  }

  private boolean clickOnPreviewButtonAndCheckTextIsPresentInPageBody(
      String currentWindow, String expectedText) {
    commandsToolbar.clickOnPreviewCommandBtnAndSelectUrl("dev-machine:eap");
    return switchToOpenedWindowAndCheckTextIsPresent(currentWindow, expectedText);
  }

  private boolean switchToOpenedWindowAndCheckTextIsPresent(
      String currentWindow, String expectedText) {
    seleniumWebDriverHelper.switchToNextWindow(currentWindow);
    seleniumWebDriverHelper.waitNoExceptions(
        () -> seleniumWebDriverHelper.waitTextContains(By.tagName("body"), expectedText),
        StaleElementReferenceException.class);

    seleniumWebDriver.close();
    seleniumWebDriver.switchTo().window(currentWindow);

    return true;
  }

  private void waitOnAvailablePreviewPage(String currentWindow, String expectedTextOnPreviewPage) {
    new WebDriverWait(seleniumWebDriver, ELEMENT_TIMEOUT_SEC)
        .until(
            (ExpectedCondition<Boolean>)
                driver -> isPreviewPageAvailable(currentWindow, expectedTextOnPreviewPage));
  }

  private Boolean isPreviewPageAvailable(String currentWindow, String expectedText) {
    consoles.clickOnPreviewUrl();
    seleniumWebDriverHelper.switchToNextWindow(currentWindow);

    if (getBodyText().contains(expectedText)) {
      seleniumWebDriver.close();
      seleniumWebDriver.switchTo().window(currentWindow);
      return true;
    }

    seleniumWebDriver.close();
    seleniumWebDriver.switchTo().window(currentWindow);
    return false;
  }

  private String getBodyText() {
    return seleniumWebDriverHelper.waitVisibilityAndGetText(By.tagName("body"));
  }
}
