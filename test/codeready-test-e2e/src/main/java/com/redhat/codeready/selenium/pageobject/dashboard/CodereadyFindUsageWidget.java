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
package com.redhat.codeready.selenium.pageobject.dashboard;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.webdriver.WebDriverWaitFactory;
import org.eclipse.che.selenium.pageobject.FindUsages;
import org.openqa.selenium.By;

@Singleton
public class CodereadyFindUsageWidget extends FindUsages {
  private SeleniumWebDriverHelper seleniumWebDriverHelper;

  @Inject
  public CodereadyFindUsageWidget(
      SeleniumWebDriver seleniumWebDriver,
      WebDriverWaitFactory webDriverWaitFactory,
      SeleniumWebDriverHelper seleniumWebDriverHelper) {
    super(seleniumWebDriver, seleniumWebDriverHelper, webDriverWaitFactory);
    this.seleniumWebDriverHelper = seleniumWebDriverHelper;
  }

  public void waitExpectedOccurences(int numberOfOccurences) {
    seleniumWebDriverHelper.waitVisibility(
        By.xpath(
            String.format(
                "//span[text()=' [%s occurrences]']", Integer.toString(numberOfOccurences))));
  }
}
