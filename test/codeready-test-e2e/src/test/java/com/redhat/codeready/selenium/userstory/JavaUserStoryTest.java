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

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.JAVA_EAP;
import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.ASSISTANT;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.FIND_DEFINITION;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.FIND_USAGES;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.QUICK_DOCUMENTATION;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.QUICK_FIX;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;
import static org.eclipse.che.selenium.pageobject.debug.DebugPanel.DebuggerActionButtons.BTN_DISCONNECT;
import static org.eclipse.che.selenium.pageobject.debug.DebugPanel.DebuggerActionButtons.EVALUATE_EXPRESSIONS;
import static org.eclipse.che.selenium.pageobject.debug.DebugPanel.DebuggerActionButtons.RESUME_BTN_ID;
import static org.eclipse.che.selenium.pageobject.debug.DebugPanel.DebuggerActionButtons.STEP_INTO;
import static org.eclipse.che.selenium.pageobject.debug.DebugPanel.DebuggerActionButtons.STEP_OUT;
import static org.eclipse.che.selenium.pageobject.debug.DebugPanel.DebuggerActionButtons.STEP_OVER;
import static org.openqa.selenium.Keys.F4;
import static org.testng.Assert.assertEquals;

import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.CodereadyDebuggerPanel;
import com.redhat.codeready.selenium.pageobject.CodereadyEditor;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyFindUsageWidget;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import javax.ws.rs.HttpMethod;
import org.eclipse.che.api.core.rest.HttpJsonRequestFactory;
import org.eclipse.che.selenium.core.client.TestProjectServiceClient;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.core.workspace.TestWorkspaceProvider;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Events;
import org.eclipse.che.selenium.pageobject.Menu;
import org.eclipse.che.selenium.pageobject.NotificationsPopupPanel;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.Wizard;
import org.eclipse.che.selenium.pageobject.dashboard.AddOrImportForm;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceDetails;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceOverview;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.eclipse.che.selenium.pageobject.debug.JavaDebugConfig;
import org.eclipse.che.selenium.pageobject.intelligent.CommandsPalette;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/** @author Musienko Maxim */
public class JavaUserStoryTest {
  private static final Logger LOG = LoggerFactory.getLogger(JavaUserStoryTest.class);
  private final String WORKSPACE = generate("JavaUserStory", 4);
  private final String PROJECT = "kitchensink-example";
  private final String PATH_TO_MAIN_PACKAGE =
      PROJECT + "/src/main/java/org/jboss/as/quickstarts/kitchensink";
  @Inject private Dashboard dashboard;
  @Inject private WorkspaceDetails workspaceDetails;
  @Inject private Workspaces workspaces;
  @Inject private WorkspaceOverview workspaceOverview;
  @Inject private CodereadyNewWorkspace newWorkspace;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private TestWorkspaceProvider testWorkspaceProvider;
  @Inject private SeleniumWebDriverHelper seleniumWebDriverHelper;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private TestWorkspaceServiceClient workspaceServiceClient;
  @Inject private AddOrImportForm addOrImportForm;
  @Inject private CommandsPalette commandsPalette;
  @Inject private Wizard wizard;
  @Inject private Consoles consoles;
  @Inject private CodereadyEditor editor;
  @Inject private HttpJsonRequestFactory requestFactory;
  @Inject private Menu menu;
  @Inject private CodereadyDebuggerPanel debugPanel;
  @Inject private JavaDebugConfig debugConfig;
  @Inject private Events events;
  @Inject private NotificationsPopupPanel notifications;
  @Inject private CodereadyFindUsageWidget findUsages;
  @Inject private TestProjectServiceClient projectServiceClient;

  private String appUrl;
  private String tabNameWithImpl = "NativeMethodAccessorImpl";

  // it is used to read workspace logs on test failure
  private TestWorkspace testWorkspace;

  @BeforeClass
  public void setUp() {
    dashboard.open();
  }

  @AfterClass
  public void tearDown() throws Exception {
    workspaceServiceClient.delete(WORKSPACE, defaultTestUser.getName());
  }

  @Test(priority = 1)
  public void createJavaEAPWorkspaceWithProjectFromDashBoard() throws Exception {
    testWorkspace = createWsFromJavaEAPStackWithTestProject(PROJECT);
  }

  @Test(priority = 2)
  public void checkMainDebuggerFeatures() throws Exception {
    setUpDebugMode();
    projectExplorer.openItemByPath(PATH_TO_MAIN_PACKAGE + "/data/MemberListProducer.java");
    editor.setBreakPointAndWaitActiveState(30);
    doGetRequestToApp();
    debugPanel.waitDebugHighlightedText("return members;");
    checkEvaluateExpression();
    checkStepInto();
    checkStepOver();
    checkStepOut();
    checkFramesAndVariablesWithResume();
    checkEndDebugSession();
  }

  @Test(priority = 3)
  public void checkCodeAssistantFeatures() throws Exception {
    String expectedTextOfInjectClass =
        "@see javax.inject.Provider\n */\n@Target({ METHOD, CONSTRUCTOR, FIELD })\n@Retention(RUNTIME)\n@Documented\npublic @interface Inject {}";
    String memberRegistrationTabName = "MemberRegistration";

    String loggerJavaDocFragment =
        "On each logging call the Logger initially performs a cheap check of the request level (e.g., SEVERE or FINE)";

    String expectedTextAfterQuickFix =
        "@Override\npublic String decorate(String s) {\n return null;\n}";

    List<String> expectedContentInAutocompleteContainer =
        Arrays.asList(
            "name : String Member",
            "setName(String name) : void Member",
            "getName() : String Member",
            "Name - java.util.jar.Attributes");

    checkGoToDeclarationFeature();
    checkFindUsagesFeature();
    checkPreviousTabFeature(memberRegistrationTabName);
    checkFindDefinitionFeature(expectedTextOfInjectClass);
    checkQuickDocumentationFeature(memberRegistrationTabName, loggerJavaDocFragment);
    checkCodeValidationFeature(memberRegistrationTabName);
    addTestFileIntoProjectByApi();
    checkQuickFixFeature(expectedTextAfterQuickFix);
    checkAutoCompletionFeature(expectedContentInAutocompleteContainer);
  }

  private void checkAutoCompletionFeature(List<String> expectedContentInAutocompleteContainer) {
    editor.goToPosition(57, 18);
    editor.launchAutocomplete();
    editor.waitProposalsIntoAutocompleteContainer(expectedContentInAutocompleteContainer);
  }

  private void checkQuickFixFeature(String expectedTextAfterQuickFix) {
    projectExplorer.openItemByPath(PATH_TO_MAIN_PACKAGE + "/util/DecoratorSample.java");
    editor.selectTabByName("Member");
    editor.goToPosition(23, 31);
    editor.typeTextIntoEditor(" DecoratorSample,");
    editor.waitMarkerInPosition(ERROR, 23);
    editor.goToPosition(23, 34);
    menu.runCommand(ASSISTANT, QUICK_FIX);
    editor.selectFirstItemIntoFixErrorPropByDoubleClick();
    editor.goToPosition(24, 18);
    menu.runCommand(ASSISTANT, QUICK_FIX);
    editor.selectFirstItemIntoFixErrorPropByDoubleClick();
    editor.goToPosition(84, 1);
    editor.waitTextIntoEditor(expectedTextAfterQuickFix);
  }

  private void checkCodeValidationFeature(String memberRegistrationTabName) {
    editor.selectTabByName(memberRegistrationTabName);
    editor.typeTextIntoEditor("2");
    editor.waitMarkerInPosition(ERROR, 28);
    editor.goToPosition(28, 18);
    menu.runCommand(ASSISTANT, QUICK_FIX);
    editor.enterTextIntoFixErrorPropByDoubleClick("Change to 'Logger' (java.util.logging)");
    editor.waitAllMarkersInvisibility(ERROR);
  }

  private void checkQuickDocumentationFeature(
      String memberRegistrationTabName, String loggerJavaDocFragment) {
    editor.selectTabByName(memberRegistrationTabName);
    editor.goToPosition(28, 17);
    menu.runCommand(ASSISTANT, QUICK_DOCUMENTATION);
    editor.checkTextToBePresentInCodereadyJavaDocPopUp(loggerJavaDocFragment);
  }

  private void checkFindDefinitionFeature(String expectedTextOfInjectClass) {
    editor.goToPosition(36, 7);
    menu.runCommand(ASSISTANT, FIND_DEFINITION);
    editor.waitActiveTabFileName("Inject.class");
    editor.waitCursorPosition(185, 25);
    editor.waitTextIntoEditor(expectedTextOfInjectClass);
  }

  private void checkPreviousTabFeature(String memberRegistrationTabName) {
    menu.runCommand(TestMenuCommandsConstants.Edit.EDIT, "gwt-debug-topmenu/Edit/switchLeftTab");
    editor.waitActiveTabFileName(memberRegistrationTabName);
    editor.waitActive();
  }

  private void checkFindUsagesFeature() {
    menu.runCommand(ASSISTANT, FIND_USAGES);
    findUsages.waitExpectedOccurences(26);
  }

  private void checkGoToDeclarationFeature() {
    projectExplorer.openItemByPath(PATH_TO_MAIN_PACKAGE + "/controller/MemberRegistration.java");
    editor.waitActive();
    editor.goToPosition(39, 14);
    editor.typeTextIntoEditor(F4.toString());
    editor.waitActiveTabFileName("Member");
    editor.waitCursorPosition(23, 20);
  }

  private void setUpDebugMode() {
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick("kitchensink-example:build and run in debug");
    consoles.waitExpectedTextIntoConsole("started in");
    menu.runCommand(
        TestMenuCommandsConstants.Run.RUN_MENU,
        TestMenuCommandsConstants.Run.EDIT_DEBUG_CONFIGURATION);
    debugConfig.createConfig(PROJECT);
    menu.runCommand(
        TestMenuCommandsConstants.Run.RUN_MENU,
        TestMenuCommandsConstants.Run.DEBUG,
        TestMenuCommandsConstants.Run.DEBUG + "/" + PROJECT);
    debugPanel.waitVariablesPanel();
    notifications.waitPopupPanelsAreClosed();
    events.clickEventLogBtn();
    events.waitExpectedMessage("Remote debugger connected");
    consoles.clickOnProcessesButton();
  }

  private TestWorkspace createWsFromJavaEAPStackWithTestProject(String kitchenExampleName)
      throws Exception {
    dashboard.selectWorkspacesItemOnDashboard();
    dashboard.waitToolbarTitleName("Workspaces");
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.typeWorkspaceName(WORKSPACE);
    newWorkspace.selectCodereadyStack(JAVA_EAP);
    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.addSampleToWorkspace(kitchenExampleName);
    newWorkspace.clickOnCreateButtonAndOpenInIDE();
    seleniumWebDriverHelper.switchToIdeFrameAndWaitAvailability();

    TestWorkspace testWorkspace = testWorkspaceProvider.getWorkspace(WORKSPACE, defaultTestUser);

    projectExplorer.waitItem(kitchenExampleName);
    events.clickEventLogBtn();
    events.waitExpectedMessage("Branch 'master' is checked out");
    consoles.clickOnProcessesButton();
    consoles.waitJDTLSProjectResolveFinishedMessage(PROJECT);
    projectExplorer.quickExpandWithJavaScript();
    addTestFileIntoProjectByApi();

    return testWorkspace;
  }

  // do request to test application if debugger for the app. has been set properly,
  // expected http response from the app. will be 504, its ok
  private void doGetRequestToApp() {
    appUrl = consoles.getPreviewUrl() + "/index.jsf";
    new Thread(
            () -> {
              try {
                requestFactory.fromUrl(appUrl).useGetMethod().request();
              } catch (Exception e) {
                // if we get 504 response code it is expected
                if (e.getMessage().contains("response code: 504")) {
                  LOG.info("Debugger has been set");
                } else {
                  LOG.error(
                      String.format(
                          "There was a problem with connecting to kitchensink-application for debug on URL '%s'",
                          appUrl),
                      e);
                }
              }
            })
        .start();
  }

  private void checkEvaluateExpression() {
    consoles.clickOnDebugTab();
    debugPanel.clickOnButton(EVALUATE_EXPRESSIONS);
    debugPanel.typeEvaluateExpression("members.size()");
    debugPanel.clickEvaluateBtn();
    debugPanel.waitExpectedResultInEvaluateExpression("1");
    debugPanel.clickCloseEvaluateBtn();
  }

  private void checkStepInto() {
    debugPanel.clickOnButton(STEP_INTO);
    editor.waitTabIsPresent(tabNameWithImpl);
    debugPanel.waitDebugHighlightedText("return invoke0(method, obj, args);");
  }

  private void checkStepOver() {
    debugPanel.clickOnButton(STEP_OVER);
    editor.waitTabIsPresent(tabNameWithImpl);
    debugPanel.waitDebugHighlightedText("return delegate.invoke(obj, args);");
  }

  private void checkStepOut() {
    debugPanel.clickOnButton(STEP_OUT);
    editor.waitTabIsPresent("Method");
    debugPanel.waitDebugHighlightedText("return ma.invoke(obj, args);");
  }

  private void checkFramesAndVariablesWithResume() {
    Stream<String> expectedValuesInVariablesWidget =
        Stream.of(
            "em=instance of org.jboss.as.jpa.container.TransactionScopedEntityManager",
            "members=instance of java.util.ArrayList");
    editor.closeAllTabs();
    debugPanel.clickOnButton(RESUME_BTN_ID);
    editor.waitTabIsPresent("MemberListProducer");
    debugPanel.waitDebugHighlightedText("return members;");
    expectedValuesInVariablesWidget.forEach(val -> debugPanel.waitTextInVariablesPanel(val));
    debugPanel.selectFrame(2);
    editor.waitTabIsPresent("NativeMethodAccessorImpl");
  }

  // after stopping debug session the test application should be available again.
  // we check this by UI parts and http request, in this case expected request code should be 200
  private void checkEndDebugSession() throws Exception {
    debugPanel.clickOnButton(BTN_DISCONNECT);
    debugPanel.waitFramesPanelIsEmpty();
    debugPanel.waitVariablesPanelIsEmpty();
    HttpURLConnection httpURLConnection = (HttpURLConnection) new URL(appUrl).openConnection();
    httpURLConnection.setRequestMethod(HttpMethod.GET);
    assertEquals(httpURLConnection.getResponseCode(), 200);
  }

  private void addTestFileIntoProjectByApi() throws Exception {
    URL resourcesOut = getClass().getResource("/projects/Decorator.java");
    String content =
        Files.readAllLines(Paths.get(resourcesOut.toURI()), Charset.forName("UTF-8"))
            .stream()
            .collect(Collectors.joining());
    String wsId = workspaceServiceClient.getByName(WORKSPACE, defaultTestUser.getName()).getId();
    String pathToFolder = PATH_TO_MAIN_PACKAGE + "/util";
    String NewFileName = "DecoratorSample.java";
    projectServiceClient.createFileInProject(wsId, pathToFolder, NewFileName, content);
  }
}
