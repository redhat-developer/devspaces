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

import static java.lang.String.format;
import static java.util.Arrays.asList;
import static org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Locators.STACK_ROW_XPATH;

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
  }

  public enum CodereadyStacks {
    JAVA_EAP("eap-default"),
    JAVA_DEFAULT("java-default"),
    VERTX("vert.x-default"),
    SPRING_BOOT("spring-boot-default"),
    WILD_FLY_SWARM("spring-boot-default"),
    DOT_NET("dotnet-default"),
    CPP("cpp-default"),
    GO("go-default"),
    JAVA_10("java10-default"),
    NODE("node-default"),
    PHP("php-default"),
    PYTHON("python-default");

    private String id;

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
    seleniumWebDriverHelper.waitAndClick(By.xpath(format(STACK_ROW_XPATH, stack.getId())));
  }

  public void waitCodereadyStacks(List<CodereadyStacks> expectedStacks) {
    expectedStacks.forEach(
        stack ->
            seleniumWebDriverHelper.waitPresence(
                By.xpath(format("//div[@data-stack-id='%s']", stack.getId()))));
  }
}
