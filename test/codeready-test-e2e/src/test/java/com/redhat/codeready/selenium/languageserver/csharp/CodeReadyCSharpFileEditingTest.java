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
package com.redhat.codeready.selenium.languageserver.csharp;

import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.BUILD_GOAL;

import org.eclipse.che.selenium.languageserver.csharp.CSharpFileEditingTest;

/**
 * @author Musienko Maxim
 * @author Aleksandr Shmaraev
 */
public class CodeReadyCSharpFileEditingTest extends CSharpFileEditingTest {

  private final String COMMAND_NAME = PROJECT_NAME + ": update dependencies";

  @Override
  protected void initLanguageServer() {
    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME, BUILD_GOAL, COMMAND_NAME, "Restore completed");

    projectExplorer.quickRevealToItemWithJavaScript(PROJECT_NAME + "/" + NAME_OF_EDITING_FILE);
    projectExplorer.openItemByPath(PROJECT_NAME + "/" + NAME_OF_EDITING_FILE);
    consoles.selectProcessByTabName("dev-machine");
    consoles.waitExpectedTextIntoConsole(LANGUAGE_SERVER_INIT_MESSAGE);
    editor.selectTabByName(NAME_OF_EDITING_FILE);
  }
}
