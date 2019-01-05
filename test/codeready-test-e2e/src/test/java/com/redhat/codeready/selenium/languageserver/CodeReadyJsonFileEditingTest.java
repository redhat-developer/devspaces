package com.redhat.codeready.selenium.languageserver;

import org.eclipse.che.selenium.languageserver.JsonFileEditingTest;

/** @author Aleksandr Shmaraev */
public class CodeReadyJsonFileEditingTest extends JsonFileEditingTest {

  private static final String PROJECT_NAME = "web-nodejs-simple";

  @Override
  protected void selectSampleProject() {
    wizard.selectSample(PROJECT_NAME);
  }
}
