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

import com.google.inject.Inject;
import com.google.inject.Singleton;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.action.ActionsFactory;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.webdriver.WebDriverWaitFactory;
import org.eclipse.che.selenium.pageobject.AskForValueDialog;
import org.eclipse.che.selenium.pageobject.CodenvyEditor;
import org.eclipse.che.selenium.pageobject.Loader;
import org.eclipse.che.selenium.pageobject.TestWebElementRenderChecker;
import org.openqa.selenium.By;

@Singleton
public class CodereadyEditor extends CodenvyEditor {
  private SeleniumWebDriverHelper seleniumWebDriverHelper;

  @Inject
  public CodereadyEditor(
      SeleniumWebDriver seleniumWebDriver,
      Loader loader,
      ActionsFactory actionsFactory,
      AskForValueDialog askForValueDialog,
      TestWebElementRenderChecker testWebElementRenderChecker,
      SeleniumWebDriverHelper seleniumWebDriverHelper,
      WebDriverWaitFactory webDriverWaitFactory) {
    super(
        seleniumWebDriver,
        loader,
        actionsFactory,
        askForValueDialog,
        testWebElementRenderChecker,
        seleniumWebDriverHelper,
        webDriverWaitFactory);
    this.seleniumWebDriverHelper = seleniumWebDriverHelper;
  }

  public void checkTextToBePresentInCodereadyJavaDocPopUp(String expectedText) {
    String rhJavaDocLocator =
        "//div[@class='textviewTooltip' and contains(@style, 'visibility: visible')]";
    seleniumWebDriverHelper.waitTextContains(By.xpath(rhJavaDocLocator), expectedText);
  }
}
