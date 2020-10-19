/*
 * Copyright (c) 2019-2020 Red Hat, Inc.
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Contributors:
 *   Red Hat, Inc. - initial API and implementation
 */
package com.redhat.codeready.selenium.pageobject;

import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.APPROVE_BUTTON_NAME;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.CONFIRM_PASSWORD_INPUT_NAME;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.EMAIL_NAME;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.FIRST_NAME_NAME;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.IDENTITY_PROVIDER_LINK_XPATH;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.LAST_NAME_NAME;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.LOGIN_BUTTON_XPATH;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.LOGIN_TITLE_ID;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.PASSWORD_INPUT_NAME;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.REGISTER_LINK_XPATH;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.SUBMIT_BUTTON_XPATH;
import static com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage.Locators.USERNAME_INPUT_NAME;
import static java.lang.String.format;
import static java.util.Arrays.asList;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.WIDGET_TIMEOUT_SEC;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import com.google.inject.name.Named;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.pageobject.ocp.OpenShiftLoginPage;
import org.eclipse.che.selenium.pageobject.site.CheLoginPage;
import org.openqa.selenium.By;
import org.openqa.selenium.TimeoutException;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.FindBy;
import org.openqa.selenium.support.PageFactory;

@Singleton
public class CodereadyOpenShiftLoginPage extends OpenShiftLoginPage {
  private final SeleniumWebDriverHelper seleniumWebDriverHelper;
  private final CheLoginPage cheLoginPage;

  @Inject(optional = true)
  @Named("env.openshift.regular.username")
  private String openShiftUsername;

  @Inject(optional = true)
  @Named("env.openshift.regular.password")
  private String openShiftPassword;

  @Inject(optional = true)
  @Named("env.openshift.regular.email")
  private String openShiftEmail;

  private static final String IDENTITY_PROVIDER_NAME = "htpasswd";

  protected interface Locators {
    String FIRST_NAME_NAME = "firstName";
    String LAST_NAME_NAME = "lastName";
    String EMAIL_NAME = "email";
    String USERNAME_INPUT_NAME = "username";
    String PASSWORD_INPUT_NAME = "password";
    String CONFIRM_PASSWORD_INPUT_NAME = "password-confirm";
    String LOGIN_TITLE_ID = "brand";
    String LOGIN_BUTTON_XPATH = "//button[@type='submit']";
    String REGISTER_LINK_XPATH = "//a[text()='Register']";
    String SUBMIT_BUTTON_XPATH = "//input[@value='Submit']";
    String APPROVE_BUTTON_NAME = "approve";
    String IDENTITY_PROVIDER_LINK_XPATH = "//a[@title='Log in with %s']";
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

  @FindBy(xpath = REGISTER_LINK_XPATH)
  private WebElement registerLink;

  @FindBy(name = APPROVE_BUTTON_NAME)
  private WebElement approveButton;

  @FindBy(id = LOGIN_TITLE_ID)
  private WebElement loginTitle;

  @FindBy(xpath = SUBMIT_BUTTON_XPATH)
  private WebElement submitButton;

  @Inject
  public CodereadyOpenShiftLoginPage(
      SeleniumWebDriver seleniumWebDriver,
      SeleniumWebDriverHelper seleniumWebDriverHelper,
      CheLoginPage cheLoginPage) {

    super(seleniumWebDriver, seleniumWebDriverHelper, cheLoginPage);
    this.seleniumWebDriverHelper = seleniumWebDriverHelper;
    this.cheLoginPage = cheLoginPage;
    PageFactory.initElements(seleniumWebDriver, this);
  }

  @Override
  public void login(String username, String password) {
    waitOnOpen();

    seleniumWebDriverHelper.setValue(usernameInput, username);
    seleniumWebDriverHelper.setValue(passwordInput, password);
    seleniumWebDriverHelper.waitAndClick(loginButton);

    waitOnClose();
  }

  @Override
  public void waitOnOpen() {
    seleniumWebDriverHelper.waitAllVisibility(
        asList(usernameInput, passwordInput, loginButton), WIDGET_TIMEOUT_SEC);
  }

  public void waitOnClose() {
    seleniumWebDriverHelper.waitInvisibility(loginTitle);
  }

  public void clickOnRegisterUserLink() {
    seleniumWebDriverHelper.waitAndClick(registerLink);
  }

  public void submit(String userName, String email) {
    seleniumWebDriverHelper.setValue(firstUsername, userName);
    seleniumWebDriverHelper.setValue(lastUsername, userName);
    seleniumWebDriverHelper.setValue(emailName, email);
    seleniumWebDriverHelper.setValue(usernameInput, "admin");

    seleniumWebDriverHelper.waitAndClick(submitButton);
  }

  public Boolean isApproveButtonVisible() {
    return seleniumWebDriverHelper.isVisible(approveButton);
  }

  public Boolean isIdentityProviderLinkVisible(String identityProviderName) {

    try {
      seleniumWebDriverHelper.waitVisibility(
          By.xpath(format(IDENTITY_PROVIDER_LINK_XPATH, identityProviderName)), 2);
    } catch (TimeoutException e) {
      return false;
    }

    return true;
  }

  public void clickOnIdentityProviderLink(String identityProviderName) {
    seleniumWebDriverHelper.waitAndClick(
        By.xpath(format(IDENTITY_PROVIDER_LINK_XPATH, identityProviderName)));
  }

  public void openshiftLogin() {
    if (isIdentityProviderLinkVisible(IDENTITY_PROVIDER_NAME)) {
      clickOnIdentityProviderLink(IDENTITY_PROVIDER_NAME);
    }

    if (isOpened()) {
      login(openShiftUsername, openShiftPassword);

      if (isApproveButtonVisible()) {
        allowPermissions();
      }

      if (isOpenshiftUpdateLoginPageVisible()) {
        submit(openShiftUsername, openShiftEmail);

        addToExistingAccount();
        cheLoginPage.loginWithPredefinedUsername("admin");
      }
    }
  }
}
