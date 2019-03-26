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

import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.ELEMENT_TIMEOUT_SEC;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.EXPECTED_MESS_IN_CONSOLE_SEC;

import org.eclipse.che.selenium.intelligencecommand.CheckIntelligenceCommandFromToolbarTest;
import org.openqa.selenium.By;
import org.openqa.selenium.StaleElementReferenceException;
import org.openqa.selenium.support.ui.ExpectedCondition;
import org.openqa.selenium.support.ui.WebDriverWait;
import org.testng.annotations.Test;

/**
 * @author Aleksandr Shmaraev
 *     <p>Note: test are being overrided in class to support proper sequence of tests (issue
 *     CRW-155).
 */
public class CodeReadyCheckIntelligenceCommandFromToolbarTest
    extends CheckIntelligenceCommandFromToolbarTest {

  @Override
  protected void checkButtonsOnToolbar(String expectedText) {
    projectExplorer.waitProjectExplorer();
    projectExplorer.waitItem(PROJECT_NAME);
    commandsToolbar.clickExecStopBtn();

    checkTestAppByPreviewUrlAndReturnToIde(currentWindow, expectedText);
    commandsToolbar.clickExecRerunBtn();
    waitExpectedTextIntoConsole();
    consoles.clickOnPreviewUrl();

    waitOnAvailablePreviewPage(currentWindow);
    commandsToolbar.waitTimerValuePattern("\\d\\d:\\d\\d");
    commandsToolbar.waitNumOfProcessCounter(3);

    checkTestAppByPreviewButtonAndReturnToIde(currentWindow);
    commandsToolbar.clickExecStopBtn();
  }

  @Override
  protected void selectSampleProject() {
    String sampleProjectName = "kitchensink-example";
    wizard.selectProjectAndCreate(sampleProjectName, PROJECT_NAME);
  }

  @Override
  protected void clickAndLaunchCommandInCommandsToolbar() {
    commandsToolbar.clickWithHoldAndLaunchCommandFromList(
        PROJECT_NAME + ": build and run in debug");
    waitExpectedTextIntoConsole();
  }

  @Override
  protected void selectProcessByTabName() {
    consoles.selectProcessByTabName(PROJECT_NAME + ": build and run in debug");
  }

  @Override
  protected void waitExpectedTextIntoConsole() {
    consoles.waitExpectedTextIntoConsole("started in", EXPECTED_MESS_IN_CONSOLE_SEC);
  }

  @Override
  protected void waitOnAvailablePreviewPage(String currentWindow) {
    String expectedTextOnPreviewPage = "Welcome to JBoss AS 7!";
    new WebDriverWait(seleniumWebDriver, ELEMENT_TIMEOUT_SEC)
        .until(
            (ExpectedCondition<Boolean>)
                driver -> isPreviewPageAvailable(currentWindow, expectedTextOnPreviewPage));
  }

  @Override
  protected void checkTestAppByPreviewUrlAndReturnToIde(String currentWindow) {
    String expectedText = "Welcome to JBoss AS 7!";
    new WebDriverWait(seleniumWebDriver, ELEMENT_TIMEOUT_SEC)
        .until(
            (ExpectedCondition<Boolean>)
                driver ->
                    clickOnPreviewUrlAndCheckTextIsPresentInPageBody(currentWindow, expectedText));
  }

  @Override
  protected void checkTestAppByPreviewUrlAndReturnToIde(String currentWindow, String expectedText) {
    new WebDriverWait(seleniumWebDriver, ELEMENT_TIMEOUT_SEC)
        .until(
            (ExpectedCondition<Boolean>)
                driver ->
                    clickOnPreviewUrlAndCheckTextIsPresentInPageBody(currentWindow, expectedText));
  }

  @Override
  protected void checkTestAppByPreviewButtonAndReturnToIde(String currentWindow) {
    String expectedText = "Welcome to JBoss AS 7!";
    new WebDriverWait(seleniumWebDriver, ELEMENT_TIMEOUT_SEC)
        .until(
            (ExpectedCondition<Boolean>)
                driver ->
                    clickOnPreviewButtonAndCheckTextIsPresentInPageBody(
                        currentWindow, expectedText));
  }

  @Override
  protected boolean clickOnPreviewButtonAndCheckTextIsPresentInPageBody(
      String currentWindow, String expectedText) {
    commandsToolbar.clickOnPreviewCommandBtnAndSelectUrl("dev-machine:eap");
    return switchToOpenedWindowAndCheckTextIsPresent(currentWindow, expectedText);
  }

  @Override
  protected boolean switchToOpenedWindowAndCheckTextIsPresent(
      String currentWindow, String expectedText) {
    seleniumWebDriverHelper.switchToNextWindow(currentWindow);
    seleniumWebDriverHelper.waitNoExceptions(
        () -> seleniumWebDriverHelper.waitTextContains(By.tagName("body"), expectedText),
        StaleElementReferenceException.class);

    seleniumWebDriver.close();
    seleniumWebDriver.switchTo().window(currentWindow);

    return true;
  }

  @Override
  protected String getBodyText() {
    return seleniumWebDriverHelper.waitVisibilityAndGetText(By.tagName("body"));
  }

  @Test
  @Override
  public void launchClonedWepAppTest() {
    super.launchClonedWepAppTest();
  }

  @Test(priority = 1)
  @Override
  public void checkButtonsOnToolbarOnOpenshift() {
    checkButtonsOnToolbar("Application is not available");
  }
}
