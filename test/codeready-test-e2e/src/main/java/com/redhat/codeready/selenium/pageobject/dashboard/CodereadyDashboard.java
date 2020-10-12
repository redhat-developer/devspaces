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
package com.redhat.codeready.selenium.pageobject.dashboard;

import com.google.inject.Inject;
import com.google.inject.name.Named;
import com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.client.TestUserPreferencesServiceClient;
import org.eclipse.che.selenium.core.client.keycloak.TestKeycloakSettingsServiceClient;
import org.eclipse.che.selenium.core.entrance.Entrance;
import org.eclipse.che.selenium.core.provider.TestDashboardUrlProvider;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.webdriver.WebDriverWaitFactory;
import org.eclipse.che.selenium.pageobject.TestWebElementRenderChecker;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.site.LoginPage;
import org.openqa.selenium.support.PageFactory;

public class CodereadyDashboard extends Dashboard {

  private final TestDashboardUrlProvider testDashboardUrlProvider;
  private final Entrance entrance;

  @Inject private CodereadyOpenShiftLoginPage codereadyOpenShiftLoginPage;

  @Inject
  public CodereadyDashboard(
      SeleniumWebDriver seleniumWebDriver,
      DefaultTestUser defaultUser,
      TestDashboardUrlProvider testDashboardUrlProvider,
      Entrance entrance,
      LoginPage loginPage,
      TestWebElementRenderChecker testWebElementRenderChecker,
      TestKeycloakSettingsServiceClient testKeycloakSettingsServiceClient,
      SeleniumWebDriverHelper seleniumWebDriverHelper,
      WebDriverWaitFactory webDriverWaitFactory,
      TestUserPreferencesServiceClient testUserPreferencesServiceClient,
      @Named("che.multiuser") boolean isMultiuser) {
    super(
        seleniumWebDriver,
        defaultUser,
        testDashboardUrlProvider,
        entrance,
        loginPage,
        testWebElementRenderChecker,
        testKeycloakSettingsServiceClient,
        seleniumWebDriverHelper,
        webDriverWaitFactory,
        testUserPreferencesServiceClient,
        isMultiuser);
    this.testDashboardUrlProvider = testDashboardUrlProvider;
    this.entrance = entrance;
    PageFactory.initElements(seleniumWebDriver, this);
  }

  @Override
  public void open() {
    seleniumWebDriver.get(testDashboardUrlProvider.get().toString());
    codereadyOpenShiftLoginPage.openshiftLogin();
    entrance.login(defaultUser);
    waitDashboardToolbarTitle();
  }
}
