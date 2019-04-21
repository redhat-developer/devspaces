/*
* Copyright (c) 2019 Red Hat, Inc.

* All rights reserved. This program and the accompanying materials
* are made available under the terms of the Eclipse Public License v2.0
* which accompanies this distribution, and is available at
* http://www.eclipse.org/legal/epl-v10.html
*
* Contributors:
*   Red Hat, Inc. - initial API and implementation
*/
package com.redhat.codeready.selenium.userstory;

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.SPRING_BOOT;
import static java.util.Arrays.stream;
import static org.eclipse.che.selenium.core.constant.TestBuildConstants.BUILD_SUCCESS;
import static org.eclipse.che.selenium.core.constant.TestBuildConstants.LISTENING_AT_ADDRESS_8000;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.BUILD_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.BUILD_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.DEBUG_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.RUN_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.ASSISTANT;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.QUICK_DOCUMENTATION;
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
public class SpringBootUserStoryTest extends AbstractUserStoryTest {
  private static final String PROJECT_NAME = "spring-boot-http-booster";
  private static final String PATH_TO_MAIN_PACKAGE =
      PROJECT_NAME + "/src/main/java/io/openshift/booster";

  private static final String[] REPORT_DEPENDENCY_ANALYSIS = {
    "Report for /projects/spring-boot-http-booster/pom.xml",
    "1) # of application dependencies : 5",
    "2) Dependencies with Licenses : ",
    "3) Suggest adding these dependencies to your application stack:",
    "4) NO usage outlier application depedencies been found",
    "5) NO alternative  application depedencies been suggested"
  };

  @Inject private Ide ide;
  @Inject private Menu menu;
  @Inject private Consoles consoles;
  @Inject private CodereadyEditor editor;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private CommandsPalette commandsPalette;

  @Override
  protected CodereadyNewWorkspace.CodereadyStacks getStackName() {
    return SPRING_BOOT;
  }

  @Override
  protected List<String> getProjects() {
    return ImmutableList.of(PROJECT_NAME);
  }

  @Test
  @Override
  public void createWorkspaceFromDashboard() throws Exception {
    super.createWorkspaceFromDashboard();
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
  public void checkSpringBootHealthCheckBoosterProjectCommands() {
    By textOnPreviewPage = By.xpath("//h2[text()='HTTP Booster']");

    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME, BUILD_GOAL, BUILD_COMMAND, BUILD_SUCCESS);

    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME, BUILD_GOAL, BUILD_COMMAND_ITEM.getItem(PROJECT_NAME), BUILD_SUCCESS);

    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME,
        RUN_GOAL,
        RUN_COMMAND_ITEM.getItem(PROJECT_NAME),
        "INFO: Setting the server's publish address to be /");
    consoles.checkWebElementVisibilityAtPreviewPage(textOnPreviewPage);

    consoles.closeProcessTabWithAskDialog(RUN_COMMAND_ITEM.getItem(PROJECT_NAME));

    consoles.executeCommandFromProcessesArea(
        "dev-machine",
        DEBUG_GOAL,
        DEBUG_COMMAND_ITEM.getItem(PROJECT_NAME),
        LISTENING_AT_ADDRESS_8000);
  }

  @Test(priority = 2)
  public void checkCodeAssistantFeatures() {
    projectExplorer.quickExpandWithJavaScript();

    projectExplorer.openItemByPath(PATH_TO_MAIN_PACKAGE + "/service/GreetingEndpoint.java");
    editor.waitActive();
    projectExplorer.openItemByPath(PATH_TO_MAIN_PACKAGE + "/service/Greeting.java");
    editor.waitActive();

    checkGoToDeclarationFeature();
    checkCodeValidationFeature();

    try {
      checkQuickDocumentationFeature();
    } catch (TimeoutException ex) {
      // remove try-catch block after issue has been resolved
      fail("Known random failure https://github.com/eclipse/che/issues/11735");
    }
  }

  private void checkGoToDeclarationFeature() {
    editor.selectTabByName("GreetingEndpoint");
    editor.goToPosition(33, 24);
    editor.typeTextIntoEditor(F4.toString());
    editor.waitActiveTabFileName("Greeting");
    editor.waitCursorPosition(29, 20);
  }

  private void checkCodeValidationFeature() {
    editor.selectTabByName("Greeting");
    editor.goToPosition(34, 17);
    editor.typeTextIntoEditor("p");
    editor.waitMarkerInPosition(ERROR, 34);

    editor.goToPosition(34, 17);
    menu.runCommand(ASSISTANT, QUICK_FIX);
    editor.enterTextIntoFixErrorPropByDoubleClick("Change to 'content'");
    editor.waitAllMarkersInvisibility(ERROR);
  }

  private void checkQuickDocumentationFeature() {
    editor.selectTabByName("Greeting");

    editor.goToPosition(33, 16);
    menu.runCommand(ASSISTANT, QUICK_DOCUMENTATION);
    editor.checkTextToBePresentInCodereadyJavaDocPopUp(
        "The Java language provides special support for the string concatenation operator ( + ), and for conversion of other objects to strings. ");
  }
}
