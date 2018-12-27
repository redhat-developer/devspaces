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
package com.redhat.codeready.selenium.debugger;

import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.COMMON_GOAL;

import org.eclipse.che.selenium.debugger.PhpProjectDebuggingTest;

/**
 * @author Dmytro Nochevnov
 * @author Aleksandr Shmaraiev
 */
public class CodeReadyPhpProjectDebuggingTest extends PhpProjectDebuggingTest {

  @Override
  protected void invokeStartCommandWithContextMenu() {
    projectExplorer.invokeCommandWithContextMenu(COMMON_GOAL, PROJECT, "start httpd");
  }

  @Override
  protected void invokeStopCommandWithContextMenu() {
    projectExplorer.invokeCommandWithContextMenu(COMMON_GOAL, PROJECT, "stop httpd");
  }
}
