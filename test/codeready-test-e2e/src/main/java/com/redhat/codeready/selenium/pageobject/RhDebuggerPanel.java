package com.redhat.codeready.selenium.pageobject;

import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.ATTACHING_ELEM_TO_DOM_SEC;

import com.google.inject.Inject;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.webdriver.WebDriverWaitFactory;
import org.eclipse.che.selenium.pageobject.CodenvyEditor;
import org.eclipse.che.selenium.pageobject.Loader;
import org.eclipse.che.selenium.pageobject.debug.DebugPanel;
import org.eclipse.che.selenium.pageobject.intelligent.CommandsExplorer;
import org.openqa.selenium.By;

public class RhDebuggerPanel extends DebugPanel {
  private SeleniumWebDriverHelper seleniumWebDriverHelper;
  private final SeleniumWebDriver seleniumWebDriver;

  @Inject
  public RhDebuggerPanel(
      SeleniumWebDriver seleniumWebDriver,
      Loader loader,
      CodenvyEditor editor,
      CommandsExplorer commandsExplorer,
      WebDriverWaitFactory webDriverWaitFactory,
      SeleniumWebDriverHelper seleniumWebDriverHelper,
      SeleniumWebDriver seleniumWebDriver1) {
    super(
        seleniumWebDriver,
        loader,
        editor,
        commandsExplorer,
        webDriverWaitFactory,
        seleniumWebDriverHelper);
    this.seleniumWebDriverHelper = seleniumWebDriverHelper;
    this.seleniumWebDriver = seleniumWebDriver1;
  }

  public void waitVariablesPanelIsEmpty() {
    seleniumWebDriverHelper.waitSuccessCondition(
        driver -> getVariables().isEmpty(), ATTACHING_ELEM_TO_DOM_SEC);
  }

  public void waitFramesPanelIsEmpty() {
    seleniumWebDriverHelper.waitTextEqualsTo(By.id("gwt-debug-debugger-frames-list"), "");
  }
}
