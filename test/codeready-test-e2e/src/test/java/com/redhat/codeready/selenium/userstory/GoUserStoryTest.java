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
package com.redhat.codeready.selenium.userstory;

import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.RUN_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.RUN_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.RUN_GOAL;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;
import static org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Stack.GO;

import com.google.common.collect.ImmutableList;
import com.google.inject.Inject;
import java.util.List;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.pageobject.CodenvyEditor;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.dashboard.CreateWorkspaceHelper;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.openqa.selenium.By;
import org.openqa.selenium.Keys;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/**
 * @author Skoryk Serhii
 * @author Aleksandr Shmaraiev
 */
public class GoUserStoryTest {
  private static final String WORKSPACE_NAME = generate("GoUserStory", 4);
  private static final String WEB_GO_PROJECT_NAME = "web-go-simple";
  private static final String GO_FILE_NAME = "main.go";
  private static final String LS_INIT_MESSAGE = "Finished running tool: /usr/bin/go build";
  private By textOnPreviewPage = By.xpath("//pre[contains(text(),'Hello there')]");

  private List<String> expectedProposals =
      ImmutableList.of("Fscan", "Fscanf", "Fscanln", "Print", "Println", "Printf");

  @Inject private Ide ide;
  @Inject private Consoles consoles;
  @Inject private CodenvyEditor editor;
  @Inject private Dashboard dashboard;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private CreateWorkspaceHelper createWorkspaceHelper;
  @Inject private TestWorkspaceServiceClient workspaceServiceClient;

  // it is used to read workspace logs on test failure
  private TestWorkspace testWorkspace;

  @BeforeClass
  public void setUp() {
    dashboard.open();
  }

  @AfterClass
  public void tearDown() throws Exception {
    workspaceServiceClient.delete(WORKSPACE_NAME, defaultTestUser.getName());
  }

  @Test
  public void checkWorkspaceCreationFromGoStack() {
    // store info about created workspace to make SeleniumTestHandler.captureTestWorkspaceLogs()
    // possible to read logs in case of test failure
    testWorkspace =
        createWorkspaceHelper.createWorkspaceFromStackWithProject(
            GO, WORKSPACE_NAME, WEB_GO_PROJECT_NAME);

    ide.switchToIdeAndWaitWorkspaceIsReadyToUse();
    projectExplorer.waitProjectInitialization(WEB_GO_PROJECT_NAME);
  }

  @Test(priority = 1)
  public void checkWebGoSimpleProjectCommands() {
    consoles.executeCommandFromProjectExplorer(
        WEB_GO_PROJECT_NAME, RUN_GOAL, RUN_COMMAND, "listening on");

    consoles.checkWebElementVisibilityAtPreviewPage(textOnPreviewPage);

    consoles.closeProcessTabWithAskDialog(RUN_COMMAND);

    consoles.executeCommandFromProjectExplorer(
        WEB_GO_PROJECT_NAME,
        RUN_GOAL,
        RUN_COMMAND_ITEM.getItem(WEB_GO_PROJECT_NAME),
        "listening on");

    consoles.checkWebElementVisibilityAtPreviewPage(textOnPreviewPage);

    consoles.closeProcessTabWithAskDialog(RUN_COMMAND_ITEM.getItem(WEB_GO_PROJECT_NAME));
  }

  @Test(priority = 1)
  public void checkLanguageServerInitialized() {
    projectExplorer.expandPathInProjectExplorerAndOpenFile(WEB_GO_PROJECT_NAME, GO_FILE_NAME);
    editor.waitTabIsPresent(GO_FILE_NAME);

    // check Golang language sever initialized
    consoles.selectProcessByTabName("dev-machine");
    consoles.waitExpectedTextIntoConsole(LS_INIT_MESSAGE);
  }

  @Test(priority = 2)
  public void checkAutocompleteFeature() {
    // preparations
    editor.selectTabByName(GO_FILE_NAME);
    editor.goToPosition(21, 17);
    editor.typeTextIntoEditor(Keys.ENTER.toString());
    editor.typeTextIntoEditor("fmt.");

    // launch autocomplete feature and check proposals list
    editor.launchAutocompleteAndWaitContainer();
    editor.waitProposalDocumentationHTML("<p>No documentation found.</p>\n");
    editor.waitProposalsIntoAutocompleteContainer(expectedProposals);

    // restore content and check error marker invisibility
    editor.deleteCurrentLine();
    editor.waitAllMarkersInvisibility(ERROR);
  }

  @Test(priority = 2)
  public void checkCodeValidationFeature() {
    editor.selectTabByName(GO_FILE_NAME);

    // make error in code and check error marker with message
    editor.waitAllMarkersInvisibility(ERROR);
    editor.goToCursorPositionVisible(1, 1);
    editor.typeTextIntoEditor("p");
    editor.waitMarkerInPosition(ERROR, 1);
    editor.moveToMarkerAndWaitAssistContent(ERROR);
    editor.waitTextIntoAnnotationAssist("expected 'package', found 'IDENT' ppackage");

    // restore content and check error marker invisibility
    editor.goToCursorPositionVisible(1, 1);
    editor.typeTextIntoEditor(Keys.DELETE.toString());
    editor.waitAllMarkersInvisibility(ERROR);
  }

  @Test(priority = 2)
  public void checkCodeLineCommentingFeature() {
    editor.selectTabByName(GO_FILE_NAME);

    // check code line commenting
    editor.goToCursorPositionVisible(1, 1);
    editor.launchCommentCodeFeature();
    editor.waitTextIntoEditor("//package main");

    // check code line uncommenting
    editor.launchCommentCodeFeature();
    editor.waitTextNotPresentIntoEditor("//package main");
  }
}
