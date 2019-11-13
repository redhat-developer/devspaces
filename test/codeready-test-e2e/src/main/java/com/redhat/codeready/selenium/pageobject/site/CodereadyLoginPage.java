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
package com.redhat.codeready.selenium.pageobject.site;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.pageobject.site.CheLoginPage;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.FindBy;

/** @author Dmytro Nochevnov TODO implement it in upstream Che 7 and remove in CRW 2.0 */
@Singleton
public class CodereadyLoginPage extends CheLoginPage {

  protected interface Locators {
    String OPEN_SHIFT_OAUTH_LINK_XPATH = "//a[@id[contains(.,'zocial-openshift-v')]]";
  }

  @FindBy(xpath = Locators.OPEN_SHIFT_OAUTH_LINK_XPATH)
  private WebElement openShiftOAuthLink;

  private final SeleniumWebDriverHelper seleniumWebDriverHelper;

  @Inject
  public CodereadyLoginPage(
      SeleniumWebDriver seleniumWebDriver, SeleniumWebDriverHelper seleniumWebDriverHelper) {
    super(seleniumWebDriver, seleniumWebDriverHelper);

    this.seleniumWebDriverHelper = seleniumWebDriverHelper;
  }

  public void loginWithOpenShiftOAuth() {
    seleniumWebDriverHelper.waitAndClick(openShiftOAuthLink);
  }
}
