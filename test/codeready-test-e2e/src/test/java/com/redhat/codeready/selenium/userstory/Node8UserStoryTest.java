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

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.NODE8;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.ASSISTANT;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.FIND_PROJECT_SYMBOL;
import static org.eclipse.che.selenium.core.utils.FileUtil.readFileToString;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;
import static org.openqa.selenium.Keys.BACK_SPACE;
import static org.testng.Assert.fail;

import com.google.common.collect.ImmutableList;
import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.CodereadyEditor;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URISyntaxException;
import java.net.URL;
import java.util.List;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import javax.ws.rs.HttpMethod;
import javax.ws.rs.core.Response;
import org.eclipse.che.selenium.core.client.TestProjectServiceClient;
import org.eclipse.che.selenium.core.constant.TestTimeoutsConstants;
import org.eclipse.che.selenium.core.utils.WaitUtils;
import org.eclipse.che.selenium.pageobject.AssistantFindPanel;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Events;
import org.eclipse.che.selenium.pageobject.Menu;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.intelligent.CommandsPalette;
import org.openqa.selenium.Keys;
import org.openqa.selenium.WebDriverException;
import org.testng.annotations.Test;

public class Node8UserStoryTest extends AbstractUserStoryTest {
  private final String PROJECT = "web-nodejs-simple";

  @Inject private ProjectExplorer projectExplorer;
  @Inject private CommandsPalette commandsPalette;
  @Inject private Consoles consoles;
  @Inject private CodereadyEditor editor;
  @Inject private Menu menu;
  @Inject private Events events;
  @Inject private TestProjectServiceClient projectServiceClient;
  @Inject private AssistantFindPanel assistantFindPanel;

  private String packageJsonText;
  private String packageJsonEditedText;

  public Node8UserStoryTest() throws IOException, URISyntaxException {
    packageJsonText =
        readFileToString(getClass().getResource("/projects/bayesian/package-json-before.txt"));
    packageJsonEditedText =
        readFileToString(getClass().getResource("/projects/bayesian/package-json-after.txt"));
  }

  @Override
  protected CodereadyNewWorkspace.CodereadyStacks getStackName() {
    return NODE8;
  }

  @Override
  protected List<String> getProjects() {
    return ImmutableList.of(PROJECT);
  }

  @Override
  @Test
  public void createWorkspaceFromDashboard() throws Exception {
    super.createWorkspaceFromDashboard();

    projectExplorer.waitItem(PROJECT);
    events.clickEventLogBtn();
    events.waitExpectedMessage("Branch 'master' is checked out");
  }

  @Test(priority = 1)
  public void runAndCheckNodeJsApp() throws Exception {
    runAndCheckHelloWorldApp();
  }

  @Test(priority = 2)
  public void checkMainLsFeatures() {
    checkHovering();
    checkCodeValidation();
    checkFindDefinition();
  }

  @Test(priority = 3)
  public void checkBayesianLsErrorMarker() throws Exception {
    final String fileName = "package.json";
    final String packageJsonFilePath = PROJECT + "/" + fileName;
    final String expectedErrorMarkerText =
        "Application dependency serve-static-1.7.1 is vulnerable: CVE-2015-1164. Recommendation: use version";

    // open file
    projectExplorer.waitItem(PROJECT);
    projectExplorer.scrollAndSelectItem(packageJsonFilePath);
    projectExplorer.waitItemIsSelected(packageJsonFilePath);
    projectExplorer.openItemByPath(packageJsonFilePath);
    editor.waitTabIsPresent(fileName);
    editor.waitTabSelection(0, fileName);
    editor.waitActive();

    // update file for test
    projectServiceClient.updateFile(
        testWorkspace.getId(), packageJsonFilePath, packageJsonEditedText);
    editor.waitTextIntoEditor(packageJsonEditedText);

    // check error marker displaying and description
    editor.waitMarkerInPosition(ERROR, 13);
    editor.clickOnMarker(ERROR, 13);
    editor.waitTextInToolTipPopup(expectedErrorMarkerText);
  }

  private void runAndCheckHelloWorldApp()
      throws InterruptedException, ExecutionException, TimeoutException {
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick(PROJECT + ":run");
    consoles.waitExpectedTextIntoConsole("Example app listening on port 3000!");
    WaitUtils.waitSuccessCondition(
        () -> {
          try {
            return isTestApplicationAvailable(consoles.getPreviewUrl());
          } catch (Exception ex) {
            throw new RuntimeException(ex.getLocalizedMessage(), ex);
          }
        },
        TestTimeoutsConstants.WIDGET_TIMEOUT_SEC,
        TestTimeoutsConstants.MULTIPLE,
        TimeUnit.SECONDS);
    consoles.waitExpectedTextIntoConsole("Example app listening on port 3000!");
  }

  private boolean isTestApplicationAvailable(String appUrl) throws IOException {
    HttpURLConnection httpURLConnection = (HttpURLConnection) new URL(appUrl).openConnection();
    httpURLConnection.setRequestMethod(HttpMethod.GET);
    return httpURLConnection.getResponseCode() == Response.Status.OK.getStatusCode();
  }

  private void checkCodeValidation() {
    editor.waitActive();
    editor.goToCursorPositionVisible(10, 9);
    editor.typeTextIntoEditor(Keys.SPACE.toString());
    editor.waitMarkerInPosition(ERROR, 10);
    editor.moveToMarker(ERROR, 10);
    editor.waitTextInToolTipPopup("Unexpected token");
    editor.goToCursorPositionVisible(10, 10);
    editor.typeTextIntoEditor(BACK_SPACE.toString());
    editor.waitAllMarkersInvisibility(ERROR);
  }

  private void checkHovering() {
    projectExplorer.quickExpandWithJavaScript();
    projectExplorer.openItemByPath(PROJECT + "/app/app.js");
    editor.moveCursorToText("console");
    editor.waitTextInHoverPopup("Used to print to stdout and stderr.");
  }

  private void checkFindDefinition() {
    editor.goToPosition(3, 8);
    menu.runCommand(ASSISTANT, FIND_PROJECT_SYMBOL);
    assistantFindPanel.waitForm();
    assistantFindPanel.clickOnInputField();
    assistantFindPanel.typeToInputField("a");
    assistantFindPanel.waitForm();
    assistantFindPanel.waitInputField();

    try {
      assistantFindPanel.waitAllNodes("/web-nodejs-simple/node_modules/express/lib/express.js");
    } catch (WebDriverException ex) {
      // remove try-catch block after issue has been resolved
      fail("Known random failure https://issues.jboss.org/browse/CRW-377", ex);
    }

    // select item in the find panel by clicking on node
    assistantFindPanel.clickOnActionNodeWithTextContains(
        "/web-nodejs-simple/node_modules/express/lib/express.js");
    assistantFindPanel.waitFormIsClosed();
    editor.waitTextIntoEditor("function createApplication()");
    editor.waitTabIsPresent("express.js");
    editor.waitCursorPosition(57, 2);
  }
}
