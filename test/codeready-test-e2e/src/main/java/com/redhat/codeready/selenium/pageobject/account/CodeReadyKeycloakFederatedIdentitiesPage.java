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
package com.redhat.codeready.selenium.pageobject.account;

import static com.redhat.codeready.selenium.pageobject.account.CodeReadyKeycloakFederatedIdentitiesPage.Locators.TITLE_XPATH;
import static java.lang.String.format;
import static java.util.Arrays.asList;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.LOAD_PAGE_TIMEOUT_SEC;
import static org.openqa.selenium.By.xpath;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.client.keycloak.TestKeycloakSettingsServiceClient;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.pageobject.dashboard.account.KeycloakFederatedIdentitiesPage;
import org.openqa.selenium.support.ui.WebDriverWait;

/** @author Dmytro Nochevnov */
@Singleton
public class CodeReadyKeycloakFederatedIdentitiesPage extends KeycloakFederatedIdentitiesPage {

  private final WebDriverWait loadPageWait;
  private final SeleniumWebDriver seleniumWebDriver;
  private final SeleniumWebDriverHelper seleniumWebDriverHelper;
  private final CodereadyKeycloakHeaderButtons codereadyKeycloakHeaderButtons;
  private final TestKeycloakSettingsServiceClient testKeycloakSettingsServiceClient;

  @Inject
  public CodeReadyKeycloakFederatedIdentitiesPage(
      SeleniumWebDriver seleniumWebDriver,
      SeleniumWebDriverHelper seleniumWebDriverHelper,
      CodereadyKeycloakHeaderButtons codereadyKeycloakHeaderButtons,
      TestKeycloakSettingsServiceClient testKeycloakSettingsServiceClient) {
    super(
        seleniumWebDriver,
        seleniumWebDriverHelper,
        codereadyKeycloakHeaderButtons,
        testKeycloakSettingsServiceClient);
    this.seleniumWebDriver = seleniumWebDriver;
    this.seleniumWebDriverHelper = seleniumWebDriverHelper;
    this.codereadyKeycloakHeaderButtons = codereadyKeycloakHeaderButtons;
    this.testKeycloakSettingsServiceClient = testKeycloakSettingsServiceClient;
    this.loadPageWait = new WebDriverWait(seleniumWebDriver, LOAD_PAGE_TIMEOUT_SEC);
  }

  interface Locators {
    String TITLE_XPATH = "//div[@class='col-md-10']//h2[text()='Federated Identities']";
  }

  @Override
  public void open() {
    String identityPageUrl =
        format(
            "%s/identity", testKeycloakSettingsServiceClient.read().getKeycloakProfileEndpoint());

    seleniumWebDriver.navigate().to(identityPageUrl);
    waitPageIsLoaded();
  }

  private void waitPageIsLoaded() {
    codereadyKeycloakHeaderButtons.waitAllHeaderButtonsAreVisible();
    waitAllBodyFieldsAndButtonsIsVisible();
  }

  private void waitAllBodyFieldsAndButtonsIsVisible() {
    asList(xpath(TITLE_XPATH)).forEach(locator -> seleniumWebDriverHelper.waitVisibility(locator));
  }
}
