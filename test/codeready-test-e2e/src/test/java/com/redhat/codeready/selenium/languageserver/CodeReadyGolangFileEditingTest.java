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
package com.redhat.codeready.selenium.languageserver;

import org.eclipse.che.selenium.languageserver.GolangFileEditingTest;
import org.testng.annotations.Test;

/**
 * @author Aleksandr Shmaraev
 *     <p>Note: test are being overrided in class to support proper sequence of tests (issue
 *     CRW-155).
 */
public class CodeReadyGolangFileEditingTest extends GolangFileEditingTest {

  @Override
  protected void waitExpectedTextIntoConsole() {
    consoles.waitExpectedTextIntoConsole("Finished running tool:");
    consoles.waitExpectedTextIntoConsole("/usr/bin/go build");
  }

  @Test
  @Override
  public void checkLanguageServerInitialized() {
    super.checkLanguageServerInitialized();
  }

  @Test(priority = 1)
  @Override
  public void checkAutocompleteFeature() {
    super.checkAutocompleteFeature();
  }

  @Test(priority = 1)
  @Override
  public void checkCodeValidationFeature() {
    super.checkCodeValidationFeature();
  }

  @Test(priority = 1)
  @Override
  public void checkFormatCodeFeature() {
    super.checkFormatCodeFeature();
  }

  @Test(priority = 1)
  @Override
  public void checkFindDefinitionFeature() {
    super.checkFindDefinitionFeature();
  }

  @Test(priority = 1)
  @Override
  public void checkFindReferencesFeature() {
    super.checkFindReferencesFeature();
  }

  @Test(priority = 1)
  @Override
  public void checkSignatureHelpFeature() {
    super.checkSignatureHelpFeature();
  }

  @Test(priority = 1)
  @Override
  public void checkGoToSymbolFeature() {
    super.checkGoToSymbolFeature();
  }

  @Test(priority = 1)
  @Override
  public void checkFindProjectSymbolFeature() {
    super.checkFindProjectSymbolFeature();
  }

  @Test(priority = 1)
  @Override
  public void checkHoverFeature() {
    super.checkHoverFeature();
  }

  @Test(priority = 2)
  public void checkRenameFeature() {
    super.checkRenameFeature();
  }
}
