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
package com.redhat.codeready.selenium.pageobject;

import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.CONFIRM_PASSWORD_INPUT_NAME;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.EMAIL_NAME;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.FIRST_NAME_NAME;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.LAST_NAME_NAME;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.LOGIN_BUTTON_XPATH;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.PASSWORD_INPUT_NAME;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.USERNAME_INPUT_NAME;
import static java.util.Arrays.asList;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.pageobject.ocp.OpenShiftLoginPage;
import org.openqa.selenium.By;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.FindBy;
import org.openqa.selenium.support.PageFactory;

@Singleton
public class CodereadyOpenShiftLoginPage extends OpenShiftLoginPage {
  private final SeleniumWebDriverHelper seleniumWebDriverHelper;

  protected interface Locators {
    String FIRST_NAME_NAME = "firstName";
    String LAST_NAME_NAME = "lastName";
    String EMAIL_NAME = "email";
    String USERNAME_INPUT_NAME = "username";
    String PASSWORD_INPUT_NAME = "password";
    String CONFIRM_PASSWORD_INPUT_NAME = "password-confirm";
    String LOGIN_BUTTON_XPATH = "//button[text()='Log In']";
  }

  @FindBy(name = FIRST_NAME_NAME)
  private WebElement firstUsername;

  @FindBy(name = LAST_NAME_NAME)
  private WebElement lastUsername;

  @FindBy(name = EMAIL_NAME)
  private WebElement emailName;

  @FindBy(name = USERNAME_INPUT_NAME)
  private WebElement usernameInput;

  @FindBy(name = PASSWORD_INPUT_NAME)
  private WebElement passwordInput;

  @FindBy(xpath = LOGIN_BUTTON_XPATH)
  private WebElement loginButton;

  @FindBy(name = CONFIRM_PASSWORD_INPUT_NAME)
  private WebElement confirmPasswordInput;

  @Inject
  public CodereadyOpenShiftLoginPage(
      SeleniumWebDriver seleniumWebDriver, SeleniumWebDriverHelper seleniumWebDriverHelper) {
    super(seleniumWebDriver, seleniumWebDriverHelper);
    this.seleniumWebDriverHelper = seleniumWebDriverHelper;

    PageFactory.initElements(seleniumWebDriver, this);
  }

  public void login(String username, String password) {
    waitOnOpen();

    seleniumWebDriverHelper.setValue(usernameInput, username);
    seleniumWebDriverHelper.setValue(passwordInput, password);
    seleniumWebDriverHelper.waitAndClick(loginButton);
  }

  public void waitOnOpen() {
    seleniumWebDriverHelper.waitAllVisibility(
        asList(usernameInput, passwordInput, loginButton), 30);
  }

  public void waitOnClose() {
    seleniumWebDriverHelper.waitAllInvisibility(
        asList(usernameInput, passwordInput, loginButton), 30);
  }

  public void clickOnRegisterUserLink() {
    seleniumWebDriverHelper.waitAndClick(By.xpath("//a[text()='Register']"));
  }

  public void submit(String userName, String userPassword, String email) {
    seleniumWebDriverHelper.setValue(firstUsername, userName);
    seleniumWebDriverHelper.setValue(lastUsername, userName);
    seleniumWebDriverHelper.setValue(emailName, email);
    seleniumWebDriverHelper.setValue(usernameInput, userName);
    seleniumWebDriverHelper.setValue(passwordInput, userPassword);
    seleniumWebDriverHelper.setValue(confirmPasswordInput, userPassword);
  }

  public void clickOnRegisterButton() {
    seleniumWebDriverHelper.waitAndClick(By.xpath("//input[@value='Register']"));
  }
}
