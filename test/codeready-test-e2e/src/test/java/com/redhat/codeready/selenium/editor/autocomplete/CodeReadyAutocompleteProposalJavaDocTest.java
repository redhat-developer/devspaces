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
package com.redhat.codeready.selenium.editor.autocomplete;

import org.eclipse.che.selenium.editor.autocomplete.AutocompleteProposalJavaDocTest;
import org.testng.annotations.BeforeMethod;
import org.testng.annotations.Test;

/**
 * @author Aleksandr Shmaraev
 *     <p>Note: test are being overrided in class to support proper sequence of tests (issue
 *     CRW-155).
 */
public class CodeReadyAutocompleteProposalJavaDocTest extends AutocompleteProposalJavaDocTest {

  @Override
  protected String getExpectedJavadocHtmlText() {
    return "<p>Returns concatination of two strings into one divided by special symbol.</p>\n"
        + "<ul>\n"
        + "<li><p><strong>Parameters:</strong></p>\n"
        + "<ul>\n"
        + "<li><p><strong>part1</strong> part 1 to concat.</p>\n"
        + "</li>\n"
        + "<li><p><strong>part2</strong> part 2 to concat.</p>\n"
        + "</li>\n"
        + "<li><p><strong>divider</strong> divider of part1 and part2.</p>\n"
        + "</li>\n"
        + "</ul>\n"
        + "</li>\n"
        + "<li><p><strong>Returns:</strong></p>\n"
        + "<ul>\n"
        + "<li>concatination of two strings into one.</li>\n"
        + "</ul>\n"
        + "</li>\n"
        + "<li><p><strong>Throws:</strong></p>\n"
        + "<ul>\n";
  }

  @Override
  protected String getProposalDocumentationHTML() {
    return "<p>Returns <code>true</code> if the argument is equal to instance. otherwise <code>false</code></p>\n"
        + "<ul>\n"
        + "<li><p><strong>Parameters:</strong></p>\n"
        + "<ul>\n"
        + "<li><strong>o</strong> an object.</li>\n"
        + "</ul>\n"
        + "</li>\n"
        + "<li><p><strong>Returns:</strong></p>\n"
        + "<ul>\n"
        + "<li>Returns <code>true</code> if the argument is equal to instance. otherwise <code>false</code></li>\n"
        + "</ul>\n"
        + "</li>\n"
        + "<li><p><strong>Since:</strong></p>\n"
        + "<ul>\n"
        + "<li>1.0</li>\n"
        + "</ul>\n"
        + "</li>\n"
        + "<li><p><strong>See Also:</strong></p>\n"
        + "<ul>\n";
  }

  @BeforeMethod
  @Override
  public void openMainClass() {
    super.openMainClass();
  }

  @Test
  @Override
  public void shouldDisplayJavaDocOfClassMethod() {
    super.shouldDisplayJavaDocOfClassMethod();
  }

  @Test
  @Override
  public void shouldWorkAroundAbsentJavaDocOfConstructor() {
    super.shouldWorkAroundAbsentJavaDocOfConstructor();
  }

  @Test
  @Override
  public void shouldDisplayAnotherModuleClassJavaDoc() {
    super.shouldDisplayAnotherModuleClassJavaDoc();
  }

  @Test
  @Override
  public void shouldReflectChangesInJavaDoc() {
    super.shouldReflectChangesInJavaDoc();
  }

  @Test
  @Override
  public void shouldDisplayJavaDocOfJreClass() {
    super.shouldDisplayJavaDocOfJreClass();
  }

  @Test
  @Override
  public void shouldNotShowJavaDocIfExternalLibDoesNotExist() {
    super.shouldNotShowJavaDocIfExternalLibDoesNotExist();
  }
}
