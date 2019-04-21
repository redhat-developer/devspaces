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

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.WILD_FLY_SWARM;
import static java.util.Arrays.stream;
import static java.util.concurrent.TimeUnit.SECONDS;
import static org.eclipse.che.selenium.core.constant.TestBuildConstants.BUILD_SUCCESS;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.LOAD_PAGE_TIMEOUT_SEC;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.MULTIPLE;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;
import static org.openqa.selenium.Keys.ENTER;

import com.google.common.collect.ImmutableList;
import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.CodereadyEditor;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.List;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeoutException;
import javax.ws.rs.HttpMethod;
import javax.ws.rs.core.Response;
import org.eclipse.che.selenium.core.utils.WaitUtils;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Events;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.MavenPluginStatusBar;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.intelligent.CommandsPalette;
import org.testng.annotations.Test;

public class WildFlyUserStoryTest extends AbstractUserStoryTest {
  private final String PROJECT = "wfswarm-rest-http";
  private final String PATH_TO_MAIN_PACKAGE =
      "wfswarm-rest-http/src/main/java/io/openshift/booster/";

  private static final String[] REPORT_DEPENDENCY_ANALYSIS = {
    "Report for /projects/wfswarm-rest-http/pom.xml",
    "1) # of application dependencies : 2",
    "2) Dependencies with Licenses : ",
    "3) Suggest adding these dependencies to your application stack:",
    "4) NO usage outlier application depedencies been found",
    "5) NO alternative  application depedencies been suggested"
  };

  @Inject private Ide ide;
  @Inject private CommandsPalette commandsPalette;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private Consoles consoles;
  @Inject private CodereadyEditor editor;
  @Inject private Events events;
  @Inject private MavenPluginStatusBar mavenPluginStatusBar;

  @Override
  protected CodereadyNewWorkspace.CodereadyStacks getStackName() {
    return WILD_FLY_SWARM;
  }

  @Override
  protected List<String> getProjects() {
    return ImmutableList.of(PROJECT);
  }

  @Test
  @Override
  public void createWorkspaceFromDashboard() throws Exception {
    super.createWorkspaceFromDashboard();

    projectExplorer.waitItem(PROJECT);
    events.clickEventLogBtn();
    events.waitExpectedMessage("Branch 'master' is checked out");
    consoles.clickOnProcessesButton();
    consoles.waitJDTLSProjectResolveFinishedMessage(PROJECT);
  }

  @Test(priority = 1)
  public void checkDependencyAnalysisCommand() {
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick("dependency_analysis");
    consoles.waitExpectedTextIntoConsole(BUILD_SUCCESS, 500);

    stream(REPORT_DEPENDENCY_ANALYSIS)
        .forEach(partOfContent -> consoles.waitExpectedTextIntoConsole(partOfContent));
  }

  @Test(priority = 1)
  public void runAndCheckWildFlyApp()
      throws InterruptedException, ExecutionException, TimeoutException {
    runAndCheckHelloWorldApp();
    checkMainJavaFeatures();
  }

  private void runAndCheckHelloWorldApp()
      throws InterruptedException, ExecutionException, TimeoutException {
    // build and launch application with UI
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick("wfswarm-rest-http:build");
    consoles.waitExpectedTextIntoConsole(BUILD_SUCCESS, 480);
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick("wfswarm-rest-http:run");
    consoles.waitExpectedTextIntoConsole("Thorntail is Ready");

    // check that application is available
    WaitUtils.waitSuccessCondition(
        () -> {
          try {
            return isTestApplicationAvailable(
                consoles.getPreviewUrl() + "/api/greeting?name=" + WORKSPACE);
          } catch (Exception ex) {
            throw new RuntimeException(ex.getLocalizedMessage(), ex);
          }
        },
        LOAD_PAGE_TIMEOUT_SEC,
        MULTIPLE,
        SECONDS);
  }

  private boolean isTestApplicationAvailable(String appUrl) throws IOException {
    HttpURLConnection httpURLConnection = (HttpURLConnection) new URL(appUrl).openConnection();
    httpURLConnection.setRequestMethod(HttpMethod.GET);
    return httpURLConnection.getResponseMessage().equals(Response.Status.OK.getReasonPhrase());
  }

  private void checkMainJavaFeatures() {
    String pathToFile = PATH_TO_MAIN_PACKAGE + "GreetingEndpoint.java";
    // check autocompletion
    projectExplorer.quickRevealToItemWithJavaScript(pathToFile);
    projectExplorer.openItemByPath(pathToFile);
    editor.waitActive();
    mavenPluginStatusBar.waitClosingInfoPanel();
    editor.goToPosition(34, 55);
    editor.typeTextIntoEditor(ENTER.toString());
    editor.typeTextIntoEditor("suf");
    editor.launchAutocomplete();
    editor.waitTextIntoEditor("\"World\";\n        suffix");

    // check codevalidation with autocompletion
    editor.waitMarkerInPosition(ERROR, 35);
    editor.goToPosition(35, 15);
    editor.typeTextIntoEditor(".to");
    editor.launchAutocomplete();
    editor.selectItemIntoAutocompleteAndPerformDoubleClick("CharArray() : char[] ");
    editor.waitTextIntoEditor("suffix.toCharArray()");
    editor.typeTextIntoEditor(";");
    editor.waitAllMarkersInvisibility(ERROR);
  }
}
