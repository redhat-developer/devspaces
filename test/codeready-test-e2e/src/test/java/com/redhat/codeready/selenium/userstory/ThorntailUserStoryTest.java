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

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.THORNTAIL;
import static java.util.Arrays.stream;
import static java.util.concurrent.TimeUnit.SECONDS;
import static org.eclipse.che.selenium.core.constant.TestBuildConstants.BUILD_SUCCESS;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.LOAD_PAGE_TIMEOUT_SEC;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.MULTIPLE;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.PREPARING_WS_TIMEOUT_SEC;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;
import static org.openqa.selenium.Keys.ENTER;
import static org.testng.Assert.fail;

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

public class ThorntailUserStoryTest extends AbstractUserStoryTest {
  private final String PROJECT = "thorntail-rest-http";
  private final String PATH_TO_MAIN_PACKAGE = PROJECT + "/src/main/java/io/thorntail/example/";

  private static final String[] REPORT_DEPENDENCY_ANALYSIS = {
    "Report for /projects/thorntail-rest-http/pom.xml",
    "1) # of application dependencies : 0",
    "2) Dependencies with Licenses : ",
    "3) Suggest adding these dependencies to your application stack:",
    "4) No usage outlier application depedencies found",
    "5) No alternative  application depedencies suggested"
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
    return THORNTAIL;
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
  public void runAndCheckThorntailApp()
      throws InterruptedException, ExecutionException, TimeoutException {
    runAndCheckHelloWorldApp();
    checkMainJavaFeatures();
  }

  private void runAndCheckHelloWorldApp()
      throws InterruptedException, ExecutionException, TimeoutException {
    // build and launch application with UI
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick("thorntail-rest-http:build");
    consoles.waitExpectedTextIntoConsole(BUILD_SUCCESS, 480);
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick("thorntail-rest-http:run");
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
    mavenPluginStatusBar.waitClosingInfoPanel(PREPARING_WS_TIMEOUT_SEC * 2);
    editor.goToPosition(33, 87);
    editor.typeTextIntoEditor(ENTER.toString());
    editor.typeTextIntoEditor("n");
    editor.launchAutocompleteAndWaitContainer();
    editor.enterAutocompleteProposal("ame : String");
    editor.waitTextIntoEditor("name\n        return new Greeting");

    // check codevalidation with autocompletion
    try {
      editor.waitMarkerInPosition(ERROR, 34);
    } catch (org.openqa.selenium.TimeoutException ex) {
      // remove try-catch block after issue has been resolved
      fail("Known permanent failure https://issues.jboss.org/browse/CRW-192");
    }

    editor.goToPosition(34, 13);
    editor.typeTextIntoEditor(".to");
    editor.waitTextIntoEditor("name.to");
    editor.launchAutocompleteAndWaitContainer();
    editor.selectItemIntoAutocompleteAndPerformDoubleClick("String() : String ");
    editor.waitTextIntoEditor("name.toString()");
    editor.typeTextIntoEditor(";");
    editor.waitAllMarkersInvisibility(ERROR);
  }
}
