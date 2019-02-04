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

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.JAVA_DEFAULT;
import static java.nio.file.Files.readAllLines;
import static java.nio.file.Paths.get;
import static java.util.Arrays.stream;
import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.eclipse.che.selenium.core.constant.TestBuildConstants.BUILD_SUCCESS;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.ASSISTANT;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.FIND_DEFINITION;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.FIND_USAGES;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.QUICK_DOCUMENTATION;
import static org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants.Assistant.QUICK_FIX;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.LOADER_TIMEOUT_SEC;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.WIDGET_TIMEOUT_SEC;
import static org.eclipse.che.selenium.core.utils.FileUtil.readFileToString;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR_OVERVIEW;
import static org.eclipse.che.selenium.pageobject.debug.DebugPanel.DebuggerActionButtons.BTN_DISCONNECT;
import static org.eclipse.che.selenium.pageobject.debug.DebugPanel.DebuggerActionButtons.EVALUATE_EXPRESSIONS;
import static org.eclipse.che.selenium.pageobject.debug.DebugPanel.DebuggerActionButtons.RESUME_BTN_ID;
import static org.eclipse.che.selenium.pageobject.debug.DebugPanel.DebuggerActionButtons.STEP_INTO;
import static org.eclipse.che.selenium.pageobject.debug.DebugPanel.DebuggerActionButtons.STEP_OUT;
import static org.eclipse.che.selenium.pageobject.debug.DebugPanel.DebuggerActionButtons.STEP_OVER;
import static org.openqa.selenium.Keys.F4;
import static org.testng.Assert.assertEquals;
import static org.testng.Assert.fail;

import com.google.common.collect.ImmutableList;
import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.CodereadyDebuggerPanel;
import com.redhat.codeready.selenium.pageobject.CodereadyEditor;
import com.redhat.codeready.selenium.pageobject.dashboard.CodeReadyCreateWorkspaceHelper;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyFindUsageWidget;
import java.io.IOException;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.charset.Charset;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.eclipse.che.selenium.core.client.TestProjectServiceClient;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.utils.HttpUtil;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Events;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.Menu;
import org.eclipse.che.selenium.pageobject.NotificationsPopupPanel;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.debug.JavaDebugConfig;
import org.eclipse.che.selenium.pageobject.intelligent.CommandsPalette;
import org.openqa.selenium.TimeoutException;
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
      PROJECT + "/src/main/java/org.jboss.as.quickstarts.kitchensinkjsp";

  private static final String[] REPORT_DEPENDENCY_ANALYSIS = {
    "Report for /projects/spring-boot-camel/pom.xml",
    "1) # of application dependencies : 3",
    "2) Dependencies with Licenses : ",
    "3) Suggest adding these dependencies to your application stack:",
    "4) NO usage outlier application depedencies been found",
    "5) NO alternative  application depedencies been suggested"
  };

  private List<String> projects = ImmutableList.of(PROJECT);

  @Inject private Ide ide;
  @Inject private Dashboard dashboard;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private TestWorkspaceServiceClient workspaceServiceClient;
  @Inject private CommandsPalette commandsPalette;
  @Inject private Consoles consoles;
  @Inject private CodereadyEditor editor;
  @Inject private Menu menu;
  @Inject private CodereadyDebuggerPanel debugPanel;
  @Inject private JavaDebugConfig debugConfig;
  @Inject private Events events;
  @Inject private NotificationsPopupPanel notifications;
  @Inject private CodereadyFindUsageWidget findUsages;
  @Inject private TestProjectServiceClient projectServiceClient;
  @Inject private CodeReadyCreateWorkspaceHelper codeReadyCreateWorkspaceHelper;

  private String tabNameWithImpl = "NativeMethodAccessorImpl";
  private String pomFileChangedText;

  // it is used to read workspace logs on test failure
  private TestWorkspace testWorkspace;

  @BeforeClass
  public void setUp() throws URISyntaxException, IOException {
    dashboard.open();
    pomFileChangedText =
        readFileToString(getClass().getResource("/projects/bayesian/pom-file-after.txt"));
  }

  @AfterClass
  public void tearDown() throws Exception {
    workspaceServiceClient.delete(WORKSPACE, defaultTestUser.getName());
  }

  @Test
  public void createJavaEAPWorkspaceWithProjectFromDashBoard() throws Exception {
    testWorkspace =
        codeReadyCreateWorkspaceHelper.createWsFromStackWithTestProject(
            WORKSPACE, JAVA_DEFAULT, projects);

    ide.switchToIdeAndWaitWorkspaceIsReadyToUse();
    projectExplorer.waitItem(PROJECT);
    events.clickEventLogBtn();
    events.waitExpectedMessage("Branch 'master' is checked out");
    consoles.clickOnProcessesButton();
    consoles.waitJDTLSProjectResolveFinishedMessage(PROJECT);
    projectExplorer.quickRevealToItemWithJavaScript(PATH_TO_MAIN_PACKAGE);
    addTestFileIntoProjectByApi();
  }

  @Test(priority = 1)
  public void checkDependencyAnalysisCommand() {
    ide.waitOpenedWorkspaceIsReadyToUse();
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick("dependency_analysis");
    consoles.waitExpectedTextIntoConsole(BUILD_SUCCESS);

    try {
      stream(REPORT_DEPENDENCY_ANALYSIS)
          .forEach(partOfContent -> consoles.waitExpectedTextIntoConsole(partOfContent));
    } catch (TimeoutException ex) {
      // remove try-catch block after issue has been resolved
      fail("Known permanent failure https://issues.jboss.org/browse/CRW-123");
    }
  }

  /**
   * Checks next debugger features:
   * <li>Debugged text highlighting
   * <li>Step into
   * <li>Step over
   * <li>Step out
   * <li>Resume
   * <li>Ending of debug session
   */
  @Test(priority = 1)
  public void checkMainDebuggerFeatures() throws Exception {
    final String fileForDebuggingTabTitle = "MemberListProducer";

    // prepare
    setUpDebugMode();
    projectExplorer.waitItem(PROJECT);
    projectExplorer.quickRevealToItemWithJavaScript(
        PATH_TO_MAIN_PACKAGE + ".data/MemberListProducer.java");
    projectExplorer.openItemByVisibleNameInExplorer("MemberListProducer.java");
    editor.waitActive();
    editor.waitTabIsPresent(fileForDebuggingTabTitle);
    editor.waitTabSelection(0, fileForDebuggingTabTitle);
    editor.waitActive();
    editor.setBreakPointAndWaitActiveState(30);
    final String appUrl = doGetRequestToApp();

    // check debug features()
    debugPanel.waitDebugHighlightedText("return members;");
    checkEvaluateExpression();
    checkStepInto();
    checkStepOver();
    checkStepOut();
    checkFramesAndVariablesWithResume();
    checkEndDebugSession(appUrl);
  }

  /**
   * Checks next code assistant features:
   * <li>Go to declaration
   * <li>Find usages
   * <li>Find definition
   * <li>Quick documentation
   * <li>Code validation
   * <li>Quick fix
   * <li>Autocompletion
   */
  @Test(priority = 2)
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
    checkCodeValidationFeature(memberRegistrationTabName);
    addTestFileIntoProjectByApi();
    checkQuickFixFeature(expectedTextAfterQuickFix);
    checkAutoCompletionFeature(expectedContentInAutocompleteContainer);

    try {
      checkQuickDocumentationFeature(memberRegistrationTabName, loggerJavaDocFragment);
    } catch (TimeoutException ex) {
      // remove try-catch block after issue has been resolved
      fail("Known random failure https://github.com/eclipse/che/issues/11735");
    }
  }

  @Test(priority = 2)
  public void checkBayesianLsErrorMarker() throws Exception {
    final String pomXmlFilePath = PROJECT + "/pom.xml";
    final String pomXmlEditorTabTitle = "jboss-as-kitchensink";

    final String expectedErrorMarkerText =
        "Application dependency commons-fileupload:commons-fileupload-1.3 is vulnerable: CVE-2014-0050 CVE-2016-3092 CVE-2016-1000031 CVE-2013-2186. Recommendation: use version 1.3.3";

    // open file
    projectExplorer.waitItem(PROJECT);
    projectServiceClient.updateFile(testWorkspace.getId(), pomXmlFilePath, pomFileChangedText);
    projectExplorer.scrollAndSelectItem(pomXmlFilePath);
    projectExplorer.waitItemIsSelected(pomXmlFilePath);
    projectExplorer.openItemByPath(pomXmlFilePath);
    editor.waitTabIsPresent(pomXmlEditorTabTitle, WIDGET_TIMEOUT_SEC);
    editor.waitTabSelection(0, pomXmlEditorTabTitle);
    editor.waitActive();

    // check error marker displaying and description
    editor.setCursorToLine(62);
    editor.waitMarkerInPosition(ERROR_OVERVIEW, 62);
    editor.clickOnMarker(ERROR, 62);
    editor.waitTextInToolTipPopup(expectedErrorMarkerText);
  }

  private void checkAutoCompletionFeature(List<String> expectedContentInAutocompleteContainer) {
    editor.goToPosition(57, 18);
    editor.launchAutocomplete();
    editor.waitProposalsIntoAutocompleteContainer(expectedContentInAutocompleteContainer);
  }

  private void checkQuickFixFeature(String expectedTextAfterQuickFix) {
    projectExplorer.quickRevealToItemWithJavaScript(
        PATH_TO_MAIN_PACKAGE + ".util/DecoratorSample.java");
    editor.selectTabByName("Member");
    editor.goToPosition(23, 31);
    editor.typeTextIntoEditor(" DecoratorSample,");
    editor.waitMarkerInPosition(ERROR_OVERVIEW, 23);
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
    editor.goToPosition(26, 15);
    editor.typeTextIntoEditor("2");
    editor.waitMarkerInPosition(ERROR_OVERVIEW, 26);
    editor.goToPosition(26, 15);
    menu.runCommand(ASSISTANT, QUICK_FIX);
    editor.enterTextIntoFixErrorPropByDoubleClick("Change to 'Logger' (java.util.logging)");
    editor.waitAllMarkersInvisibility(ERROR_OVERVIEW, LOADER_TIMEOUT_SEC);
  }

  private void checkQuickDocumentationFeature(
      String memberRegistrationTabName, String loggerJavaDocFragment) {
    editor.selectTabByName(memberRegistrationTabName);
    editor.goToPosition(28, 17);
    menu.runCommand(ASSISTANT, QUICK_DOCUMENTATION);
    editor.checkTextToBePresentInCodereadyJavaDocPopUp(loggerJavaDocFragment);
  }

  private void checkFindDefinitionFeature(String expectedTextOfInjectClass) {
    editor.goToPosition(31, 7);
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
    findUsages.waitExpectedOccurences(25);
  }

  private void checkGoToDeclarationFeature() {
    projectExplorer.quickRevealToItemWithJavaScript(
        PATH_TO_MAIN_PACKAGE + ".controller/MemberRegistration.java");
    projectExplorer.openItemByVisibleNameInExplorer("MemberRegistration.java");
    editor.waitActive();
    editor.goToPosition(34, 14);
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

  // do request to test application if debugger for the app. has been set properly,
  // expected http response from the app. will be 504, its ok
  private String doGetRequestToApp() {
    final String appUrl = consoles.getPreviewUrl() + "/index.jsf";
    int responseCode = -1;

    try {
      responseCode = HttpUtil.getUrlResponseCode(appUrl);
    } catch (Exception e) {
      // The "504" response code it is expected
      if (504 == responseCode) {
        LOG.info("Debugger has been set");
        return appUrl;
      }

      final String errorMessage =
          String.format(
              "There was a problem with connecting to kitchensink-application for debug on URL '%s'",
              appUrl);
      LOG.error(errorMessage, e);

      return appUrl;
    }

    return appUrl;
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
  private void checkEndDebugSession(String appUrl) throws Exception {
    debugPanel.clickOnButton(BTN_DISCONNECT);
    debugPanel.waitFramesPanelIsEmpty();
    debugPanel.waitVariablesPanelIsEmpty();

    final int responseCode = HttpUtil.getUrlResponseCode(appUrl);
    assertEquals(responseCode, 200);
  }

  private void addTestFileIntoProjectByApi() throws Exception {
    URL resourcesOut = getClass().getResource("/projects/Decorator.java");
    String content =
        readAllLines(get(resourcesOut.toURI()), Charset.forName("UTF-8"))
            .stream()
            .collect(Collectors.joining());
    String wsId = workspaceServiceClient.getByName(WORKSPACE, defaultTestUser.getName()).getId();
    String pathToFolder = PROJECT + "/src/main/java/org/jboss/as/quickstarts/kitchensinkjsp/util";
    String NewFileName = "DecoratorSample.java";
    projectServiceClient.createFileInProject(wsId, pathToFolder, NewFileName, content);
  }
}
