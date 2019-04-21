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

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.GO;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.RUN_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.RUN_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.RUN_GOAL;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;

import com.google.common.collect.ImmutableList;
import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import java.util.List;
import org.eclipse.che.selenium.pageobject.CodenvyEditor;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.openqa.selenium.By;
import org.openqa.selenium.Keys;
import org.testng.annotations.Test;

/**
 * @author Skoryk Serhii
 * @author Aleksandr Shmaraiev
 */
public class GoUserStoryTest extends AbstractUserStoryTest {
  private static final String WEB_GO_PROJECT_NAME = "web-go-simple";
  private static final String GO_FILE_NAME = "main.go";
  private static final String LS_INIT_MESSAGE = "Finished running tool: ";
  private static final String LS_GO_BUILD_MESSAGE = "usr/bin/go build";

  private By textOnPreviewPage = By.xpath("//pre[contains(text(),'Hello there')]");
  private List<String> projects = ImmutableList.of(WEB_GO_PROJECT_NAME);
  private List<String> expectedProposals =
      ImmutableList.of("Fscan", "Fscanf", "Fscanln", "Print", "Println", "Printf");

  @Inject private Consoles consoles;
  @Inject private CodenvyEditor editor;
  @Inject private ProjectExplorer projectExplorer;

  @Override
  protected CodereadyNewWorkspace.CodereadyStacks getStackName() {
    return GO;
  }

  @Override
  protected List<String> getProjects() {
    return ImmutableList.of(WEB_GO_PROJECT_NAME);
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
    consoles.waitExpectedTextIntoConsole(LS_GO_BUILD_MESSAGE);
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
