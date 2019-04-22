/*
* Copyright (c) 2019 Red Hat, Inc.

* All rights reserved. This program and the accompanying materials
* are made available under the terms of the Eclipse Public License v2.0
* which accompanies this distribution, and is available at
* http://www.eclipse.org/legal/epl-2.0
*
* Contributors:
*   Red Hat, Inc. - initial API and implementation
*/
package com.redhat.codeready.selenium.userstory;

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.FUSE;
import static java.util.Arrays.stream;
import static org.eclipse.che.selenium.core.constant.TestBuildConstants.BUILD_SUCCESS;
import static org.eclipse.che.selenium.core.constant.TestBuildConstants.LISTENING_AT_ADDRESS;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.BUILD_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.BUILD_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.DEBUG_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.RUN_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.ASSISTANT;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.QUICK_FIX;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.BUILD_GOAL;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.DEBUG_GOAL;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.RUN_GOAL;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;
import static org.openqa.selenium.Keys.F4;
import static org.testng.Assert.fail;

import com.google.common.collect.ImmutableList;
import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.CodereadyEditor;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import java.util.List;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.Menu;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.intelligent.CommandsPalette;
import org.openqa.selenium.By;
import org.openqa.selenium.TimeoutException;
import org.testng.annotations.Test;

/** @author Skoryk Serhii */
public class RedHatFuseUserStoryTest extends AbstractUserStoryTest {
  private static final String PROJECT_NAME = "fuse-rest-http-booster";
  private static final String PATH_TO_MAIN_PACKAGE =
      PROJECT_NAME + "/src/main/java/com/redhat/fuse/boosters/rest/http";
  private static final String LS_INIT_MESSAGE =
      "Initialized language server 'org.eclipse.che.plugin.camel.server.languageserver'";

  private static final String[] REPORT_DEPENDENCY_ANALYSIS = {
    "Report for /projects/fuse-rest-http-booster/pom.xml",
    "1) # of application dependencies : ",
    "2) Dependencies with Licenses : ",
    "3) Suggest adding these dependencies to your application stack:",
    "4) NO usage outlier application depedencies been found",
    "5) NO alternative  application depedencies been suggested"
  };

  private By textOnPreviewPage =
      By.xpath("//h1[contains(text(),'REST API Level 0 - Red Hat Fuse')]");

  @Inject private Ide ide;
  @Inject private Menu menu;
  @Inject private Consoles consoles;
  @Inject private CodereadyEditor editor;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private CommandsPalette commandsPalette;

  @Override
  protected CodereadyNewWorkspace.CodereadyStacks getStackName() {
    return FUSE;
  }

  @Override
  protected List<String> getProjects() {
    return ImmutableList.of(PROJECT_NAME);
  }

  @Test
  @Override
  public void createWorkspaceFromDashboard() throws Exception {
    super.createWorkspaceFromDashboard();

    // check Apache Camel language server initialized
    consoles.waitExpectedTextIntoConsole(LS_INIT_MESSAGE);
    consoles.waitJDTLSProjectResolveFinishedMessage(PROJECT_NAME);
  }

  @Test(priority = 1)
  public void checkDependencyAnalysisCommand() {
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick("dependency_analysis");
    consoles.waitExpectedTextIntoConsole(BUILD_SUCCESS);

    stream(REPORT_DEPENDENCY_ANALYSIS)
        .forEach(partOfContent -> consoles.waitExpectedTextIntoConsole(partOfContent));
  }

  @Test(priority = 1)
  public void checkFuseRestHttpBoosterProjectCommands() {
    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME, BUILD_GOAL, BUILD_COMMAND, BUILD_SUCCESS);

    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME, BUILD_GOAL, BUILD_COMMAND_ITEM.getItem(PROJECT_NAME), BUILD_SUCCESS);

    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME, RUN_GOAL, RUN_COMMAND_ITEM.getItem(PROJECT_NAME), "Started Application in");
    consoles.checkWebElementVisibilityAtPreviewPage(textOnPreviewPage);
    consoles.closeProcessTabWithAskDialog(RUN_COMMAND_ITEM.getItem(PROJECT_NAME));

    consoles.executeCommandFromProcessesArea(
        "dev-machine", DEBUG_GOAL, DEBUG_COMMAND_ITEM.getItem(PROJECT_NAME), LISTENING_AT_ADDRESS);
  }

  @Test(priority = 2)
  public void checkCodeAssistantFeatures() {
    projectExplorer.quickRevealToItemWithJavaScript(PATH_TO_MAIN_PACKAGE + "/Application.java");
    projectExplorer.openItemByPath(PATH_TO_MAIN_PACKAGE + "/Application.java");
    editor.waitActive();

    checkGoToDeclarationFeature();
    checkCodeValidationFeature();
  }

  private void checkGoToDeclarationFeature() {
    editor.selectTabByName("Application");
    editor.goToPosition(13, 17);
    editor.typeTextIntoEditor(F4.toString());
    editor.waitActiveTabFileName("SpringApplication.class");
    editor.waitCursorPosition(148, 31);
  }

  private void checkCodeValidationFeature() {
    editor.closeAllTabs();
    projectExplorer.openItemByPath(PATH_TO_MAIN_PACKAGE + "/Application.java");
    editor.waitActive();
    editor.goToPosition(13, 27);
    editor.typeTextIntoEditor("r");
    editor.waitMarkerInPosition(ERROR, 13);

    editor.goToPosition(13, 28);
    menu.runCommand(ASSISTANT, QUICK_FIX);

    try {
      editor.enterTextIntoFixErrorPropByDoubleClick("Change to 'run(..)'");
    } catch (TimeoutException ex) {
      // remove try-catch block after issue has been resolved
      fail("Known permanent failure https://issues.jboss.org/browse/CRW-78");
    }

    editor.waitAllMarkersInvisibility(ERROR);
  }
}
