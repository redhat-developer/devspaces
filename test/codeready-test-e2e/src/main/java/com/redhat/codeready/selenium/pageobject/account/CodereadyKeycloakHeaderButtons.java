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
package com.redhat.codeready.selenium.pageobject.account;

import static org.openqa.selenium.By.xpath;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import java.util.Arrays;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.pageobject.dashboard.account.KeycloakHeaderButtons;
import org.openqa.selenium.By;

/**
 * @author Igor Ohrimenko
 * @author Aleksandr Shmaraiev
 */
@Singleton
public class CodereadyKeycloakHeaderButtons extends KeycloakHeaderButtons {
  public enum Button {
    ACCOUNT("Account"),
    PASSWORD("Password"),
    AUTHENTICATOR("Authenticator"),
    FEDERATED_IDENTITIES("Federated Identity"),
    SESSIONS("Sessions"),
    APPLICATIONS("Applications");

    private static final String BUTTON_XPATH_TEMPLATE =
        "//div[@class='bs-sidebar col-sm-3']//a[text()='%s']";

    private final String text;

    Button(String text) {
      this.text = text;
    }

    private By getXpath() {
      return xpath(String.format(BUTTON_XPATH_TEMPLATE, text));
    }
  }

  private SeleniumWebDriverHelper seleniumWebDriverHelper;

  @Inject
  public CodereadyKeycloakHeaderButtons(SeleniumWebDriverHelper seleniumWebDriverHelper) {
    super(seleniumWebDriverHelper);
    this.seleniumWebDriverHelper = seleniumWebDriverHelper;
  }

  /** wait until all buttons which placed in the header of the page will be visible */
  @Override
  public void waitAllHeaderButtonsAreVisible() {
    Arrays.asList(
            Button.ACCOUNT.getXpath(),
            Button.PASSWORD.getXpath(),
            Button.AUTHENTICATOR.getXpath(),
            Button.SESSIONS.getXpath(),
            Button.APPLICATIONS.getXpath())
        .forEach(locator -> seleniumWebDriverHelper.waitVisibility(locator));
  }

  public void clickOnButton(Button button) {
    seleniumWebDriverHelper.waitAndClick(button.getXpath());
  }
}
