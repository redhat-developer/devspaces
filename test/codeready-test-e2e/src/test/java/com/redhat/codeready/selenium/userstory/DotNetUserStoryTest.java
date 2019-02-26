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

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.DOT_NET;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.RUN_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestCommandsConstants.UPDATE_DEPENDENCIES_COMMAND;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.RUN_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestIntelligentCommandsConstants.CommandItem.UPDATE_DEPENDENCIES_COMMAND_ITEM;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.BUILD_GOAL;
import static org.eclipse.che.selenium.core.constant.TestProjectExplorerContextMenuConstants.ContextMenuCommandGoals.RUN_GOAL;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.LOADER_TIMEOUT_SEC;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.INFO;

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

/** @author Skoryk Serhii */
public class DotNetUserStoryTest extends AbstractUserStoryTest {
  private static final String PROJECT_NAME = "dotnet-web-simple";
  private static final String LANGUAGE_SERVER_INIT_MESSAGE =
      "Initialized language server 'org.eclipse.che.plugin.csharp.languageserver";
  private static final String NAME_OF_EDITING_FILE = "Program.cs";

  @Inject private Consoles consoles;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private CodenvyEditor editor;

  @Override
  protected CodereadyNewWorkspace.CodereadyStacks getStackName() {
    return DOT_NET;
  }

  @Override
  protected List<String> getProjects() {
    return ImmutableList.of(PROJECT_NAME);
  }

  @Test(priority = 1)
  public void checkDotnetWebSimpleProjectCommands() {
    By textOnPreviewPage = By.xpath("//pre[text()='Hello World!']");

    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME, BUILD_GOAL, UPDATE_DEPENDENCIES_COMMAND, "Restore completed");
    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME,
        BUILD_GOAL,
        UPDATE_DEPENDENCIES_COMMAND_ITEM.getItem(PROJECT_NAME),
        "Restore completed");

    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME, RUN_GOAL, RUN_COMMAND, "Application started.");
    consoles.checkWebElementVisibilityAtPreviewPage(textOnPreviewPage);
    consoles.closeProcessTabWithAskDialog("run");

    consoles.executeCommandFromProjectExplorer(
        PROJECT_NAME, RUN_GOAL, RUN_COMMAND_ITEM.getItem(PROJECT_NAME), "Application started.");
    consoles.checkWebElementVisibilityAtPreviewPage(textOnPreviewPage);
  }

  @Test(priority = 2)
  public void checkBasicCSharpLanguageServerFeatures() {
    initLanguageServer();

    checkCodeValidation();
    checkAutocompleteFeature();
  }

  public void checkHoveringFeature() {
    String expectedTextInHoverPopUp =
        "Microsoft.AspNetCore.Hosting.IWebHost Represents a configured web host.";

    editor.moveCursorToText(" IWebHost ");
    editor.waitTextInHoverPopup(expectedTextInHoverPopUp);
  }

  public void checkCodeCommentFeature() {
    editor.goToPosition(13, 1);
    editor.launchCommentCodeFeature();
    editor.waitTextIntoEditor("//    public class Program");

    editor.launchCommentCodeFeature();
    editor.waitAllMarkersInvisibility(ERROR);
  }

  public void checkCodeValidation() {
    editor.waitAllMarkersInvisibility(ERROR, LOADER_TIMEOUT_SEC);
    editor.goToPosition(24, 12);
    editor.typeTextIntoEditor(Keys.BACK_SPACE.toString());
    editor.waitMarkerInPosition(ERROR, 24);

    editor.goToPosition(24, 11);
    editor.typeTextIntoEditor(";");
    editor.waitMarkerInvisibility(ERROR, 24);
  }

  private void checkAutocompleteFeature() {
    editor.deleteCurrentLine();

    editor.goToCursorPositionVisible(23, 49);
    editor.typeTextIntoEditor(".");
    editor.launchAutocomplete();
    editor.enterAutocompleteProposal("Build ");
    editor.waitTextIntoEditor("Build");
    editor.typeTextIntoEditor("();");
    editor.waitTextIntoEditor("Build();");
    editor.waitAllMarkersInvisibility(ERROR, LOADER_TIMEOUT_SEC);
  }

  private void initLanguageServer() {
    projectExplorer.quickRevealToItemWithJavaScript(PROJECT_NAME + "/" + NAME_OF_EDITING_FILE);
    projectExplorer.openItemByPath(PROJECT_NAME + "/" + NAME_OF_EDITING_FILE);

    projectExplorer.waitItem(PROJECT_NAME + "/obj");
    projectExplorer.waitItem(PROJECT_NAME + "/bin");
    consoles.selectProcessByTabName("dev-machine");
    consoles.waitExpectedTextIntoConsole(LANGUAGE_SERVER_INIT_MESSAGE);

    editor.closeAllTabs();

    projectExplorer.openItemByPath(PROJECT_NAME + "/" + NAME_OF_EDITING_FILE);
    editor.waitActive();
    editor.waitCodeAssistMarkers(INFO);
  }
}
