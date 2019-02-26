package com.redhat.codeready.selenium.languageserver;

import org.eclipse.che.selenium.languageserver.JsonFileEditingTest;
import org.testng.annotations.Test;

/**
 * @author Aleksandr Shmaraev
 *     <p>Note: test are being overrided in class to support proper sequence of tests (issue
 *     CRW-155).
 */
public class CodeReadyJsonFileEditingTest extends JsonFileEditingTest {

  private static final String PROJECT_NAME = "web-nodejs-simple";

  @Override
  protected void selectSampleProject() {
    wizard.selectSample(PROJECT_NAME);
  }

  @Test
  @Override
  public void checkLanguageServerInitialized() {
    super.checkLanguageServerInitialized();
  }

  @Test(priority = 1)
  @Override
  public void checkCodeValidationFeature() {
    super.checkCodeValidationFeature();
  }

  @Test(priority = 1)
  @Override
  public void checkAutocompleteFeature() {
    super.checkAutocompleteFeature();
  }

  @Test(priority = 1)
  @Override
  public void checkHoverFeature() {
    super.checkHoverFeature();
  }

  @Test(priority = 2)
  @Override
  public void checkGoToSymbolFeature() {
    super.checkGoToSymbolFeature();
  }
}
