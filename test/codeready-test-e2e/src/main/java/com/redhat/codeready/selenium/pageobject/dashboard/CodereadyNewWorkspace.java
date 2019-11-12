/*
 * Copyright (c) 2019 Red Hat, Inc.
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Contributors:
 *   Red Hat, Inc. - initial API and implementation
 */
package com.redhat.codeready.selenium.pageobject.dashboard;

import static java.lang.String.format;
import static java.util.Arrays.asList;
import static java.util.stream.Collectors.toList;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.ELEMENT_TIMEOUT_SEC;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import java.util.List;
import java.util.Optional;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.webdriver.WebDriverWaitFactory;
import org.eclipse.che.selenium.pageobject.TestWebElementRenderChecker;
import org.eclipse.che.selenium.pageobject.dashboard.AddOrImportForm;
import org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace;
import org.openqa.selenium.By;

/**
 * @author Musienko Maxim
 * @author Dmytro Nochevnov
 */
@Singleton
public class CodereadyNewWorkspace extends NewWorkspace {

  private SeleniumWebDriverHelper seleniumWebDriverHelper;
  private final TestWebElementRenderChecker testWebElementRenderChecker;

  private static final String WORKSPACE_CREATED_DIALOG =
      "//md-dialog/che-popup[@title='Workspace Is Created']";
  private static final String WORKSPACE_CREATED_DIALOG_CLOSE_BUTTON_XPATH =
      "//md-dialog/che-popup[@title='Workspace Is Created']//i";
  private static final String EDIT_WORKSPACE_DIALOG_BUTTON =
      "//span[text()='Create & Proceed Editing']";
  private static final String OPEN_IN_IDE_DIALOG_BUTTON =
      "//che-button-default//span[text()='Open']";

  @Inject
  public CodereadyNewWorkspace(
      SeleniumWebDriver seleniumWebDriver,
      SeleniumWebDriverHelper seleniumWebDriverHelper,
      WebDriverWaitFactory webDriverWaitFactory,
      TestWebElementRenderChecker testWebElementRenderChecker,
      AddOrImportForm addOrImportForm) {
    super(
        seleniumWebDriver,
        seleniumWebDriverHelper,
        webDriverWaitFactory,
        testWebElementRenderChecker,
        addOrImportForm);
    this.seleniumWebDriverHelper = seleniumWebDriverHelper;
    this.testWebElementRenderChecker = testWebElementRenderChecker;
  }

  public enum CodereadyStacks {
    JBOSS_EAP("eap-default"),
    JAVA_DEFAULT("java-default"),
    FUSE("fuse-default"),
    VERTX("vert.x-default"),
    SPRING_BOOT("spring-boot-default"),
    THORNTAIL("thorntail-default"),
    DOT_NET("dotnet-default"),
    CPP("cpp-default"),
    GO("go-default"),
    JAVA_10("java10-default"),
    NODE8("node-default"),
    NODE10("node10-default"),
    PHP("php-default"),
    PYTHON("python-default");

    private final String id;

    CodereadyStacks(String id) {
      this.id = id;
    }

    public static CodereadyStacks getById(String id) {
      Optional<CodereadyStacks> first =
          asList(values()).stream().filter(stack -> stack.getId().equals(id)).findFirst();
      first.orElseThrow(() -> new RuntimeException(format("Stack with id '%s' not found.", id)));
      return first.get();
    }

    public String getId() {
      return this.id;
    }
  }

  public void selectCodereadyStack(CodereadyStacks stack) {
    waitCodereadyStacks(asList(stack));
    seleniumWebDriverHelper.waitAndClick(
        By.xpath(format("//div[@data-stack-id='%s']", stack.getId())));
  }

  public void waitCodereadyStacks(List<CodereadyStacks> expectedStacks) {
    expectedStacks.forEach(
        stack ->
            seleniumWebDriverHelper.waitPresence(
                By.xpath(format("//div[@data-stack-id='%s']", stack.getId()))));
  }

  public int getCodereadyStacksCount() {
    return seleniumWebDriverHelper
        .waitPresenceOfAllElements(By.xpath("//div[@data-stack-id]"))
        .size();
  }

  public void waitCodereadyStacksOrder(List<CodereadyStacks> expectedOrder) {
    seleniumWebDriverHelper.waitSuccessCondition(
        driver -> expectedOrder.equals(getCodereadyAvailableStacks()), 20);
  }

  public List<CodereadyStacks> getCodereadyAvailableStacks() {
    return seleniumWebDriverHelper
        .waitPresenceOfAllElements(By.xpath("//div[@data-stack-id]"))
        .stream()
        .map(webElement -> CodereadyStacks.getById(webElement.getAttribute("data-stack-id")))
        .collect(toList());
  }

  public void waitWorkspaceCreatedDialogIsVisible() {
    testWebElementRenderChecker.waitElementIsRendered(
        By.xpath(WORKSPACE_CREATED_DIALOG), ELEMENT_TIMEOUT_SEC);
  }

  public void closeWorkspaceCreatedDialog() {
    seleniumWebDriverHelper.waitAndClick(By.xpath(WORKSPACE_CREATED_DIALOG_CLOSE_BUTTON_XPATH));
  }

  public void waitWorkspaceCreatedDialogDisappearance() {
    seleniumWebDriverHelper.waitInvisibility(
        By.xpath(WORKSPACE_CREATED_DIALOG), ELEMENT_TIMEOUT_SEC);
  }

  public void clickOnEditWorkspaceButton() {
    seleniumWebDriverHelper.waitAndClick(
        By.xpath(EDIT_WORKSPACE_DIALOG_BUTTON), ELEMENT_TIMEOUT_SEC);
  }

  public void clickOnOpenInIDEButton() {
    seleniumWebDriverHelper.waitAndClick(By.xpath(OPEN_IN_IDE_DIALOG_BUTTON), ELEMENT_TIMEOUT_SEC);
  }
}
