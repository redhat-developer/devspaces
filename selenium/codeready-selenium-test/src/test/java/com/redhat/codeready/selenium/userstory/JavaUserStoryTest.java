package com.redhat.codeready.selenium.userstory;

import static org.eclipse.che.commons.lang.NameGenerator.generate;

import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import org.eclipse.che.api.core.rest.HttpJsonRequestFactory;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.workspace.TestWorkspaceProvider;
import org.eclipse.che.selenium.pageobject.CodenvyEditor;
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
import org.eclipse.che.selenium.pageobject.debug.DebugPanel;
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
  @Inject private CodenvyEditor editor;
  @Inject private HttpJsonRequestFactory requestFactory;
  @Inject private Menu menu;
  @Inject private DebugPanel debugPanel;
  @Inject private JavaDebugConfig debugConfig;
  @Inject private Events events;
  @Inject private NotificationsPopupPanel notifications;

  private String workspaceName;

  @BeforeClass
  public void setUp() {
    dashboard.open();
  }

  @AfterClass
  public void tearDown() throws Exception {
    workspaceServiceClient.delete(WORKSPACE, defaultTestUser.getName());
  }

  @Test(priority = 1)
  public void createJavaEAPWorkspaceWithProjectFromDashBoard() {
    createWsFromJavaEAPStackWithTestProject(PROJECT);
  }

  @Test(priority = 2)
  public void checkMainDebuggerFeatures() {
    setUpDebugMode();
    projectExplorer.openItemByPath(
        PROJECT
            + "/src/main/java/org/jboss/as/quickstarts/kitchensink/data/MemberListProducer.java");
    editor.setBreakPointAndWaitActiveState(30);
    doGetRequestToApp();
    debugPanel.waitDebugHighlightedText("return members;");
    checkEvaluateExpression();
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

  private void createWsFromJavaEAPStackWithTestProject(String kitchenExampleName) {
    dashboard.selectWorkspacesItemOnDashboard();
    dashboard.waitToolbarTitleName("Workspaces");
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.typeWorkspaceName(WORKSPACE);
    newWorkspace.selectCodereadyStack(CodereadyNewWorkspace.CodereadyStacks.JAVA_EAP);
    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.addSampleToWorkspace(kitchenExampleName);
    newWorkspace.clickOnCreateButtonAndOpenInIDE();
    seleniumWebDriverHelper.switchToIdeFrameAndWaitAvailability();
    projectExplorer.waitItem(kitchenExampleName);
    events.clickEventLogBtn();
    events.waitExpectedMessage("Branch 'master' is checked out");
    projectExplorer.quickExpandWithJavaScript();
  }

  private void doGetRequestToApp() {
    String previewUrl = consoles.getPreviewUrl() + "/index.jsf";
    new Thread(
            () -> {
              try {
                requestFactory.fromUrl(previewUrl).useGetMethod().request();
              } catch (Exception e) {
                if (e.getMessage().contains("response code: 502")) {
                  LOG.info("Debugger is set");
                } else {
                  LOG.error(
                      String.format(
                          "There was a problem with connecting to kitchensink-application for debug on URL '%s'",
                          previewUrl),
                      e);
                }
              }
            })
        .start();
  }

  private void checkEvaluateExpression() {
    consoles.clickOnDebugTab();
    debugPanel.clickOnButton(DebugPanel.DebuggerActionButtons.EVALUATE_EXPRESSIONS);
    debugPanel.typeEvaluateExpression("members.size()");
    debugPanel.clickEvaluateBtn();
    debugPanel.waitExpectedResultInEvaluateExpression("1");
  }
}
