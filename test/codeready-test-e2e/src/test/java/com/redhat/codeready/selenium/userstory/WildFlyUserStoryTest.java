package com.redhat.codeready.selenium.userstory;

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.WILD_FLY_SWARM;
import static java.util.concurrent.TimeUnit.SECONDS;
import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.eclipse.che.selenium.core.constant.TestBuildConstants.BUILD_SUCCESS;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.LOAD_PAGE_TIMEOUT_SEC;
import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.MULTIPLE;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.MarkerLocator.ERROR;
import static org.openqa.selenium.Keys.ENTER;

import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.CodereadyDebuggerPanel;
import com.redhat.codeready.selenium.pageobject.CodereadyEditor;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyFindUsageWidget;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import javax.ws.rs.HttpMethod;
import javax.ws.rs.core.Response;
import org.eclipse.che.api.core.rest.HttpJsonRequestFactory;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.client.TestProjectServiceClient;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.constant.TestTimeoutsConstants;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.utils.WaitUtils;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.core.workspace.TestWorkspaceProvider;
import org.eclipse.che.selenium.pageobject.AssistantFindPanel;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Events;
import org.eclipse.che.selenium.pageobject.MavenPluginStatusBar;
import org.eclipse.che.selenium.pageobject.Menu;
import org.eclipse.che.selenium.pageobject.NotificationsPopupPanel;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.Wizard;
import org.eclipse.che.selenium.pageobject.dashboard.AddOrImportForm;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceDetails;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceOverview;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.eclipse.che.selenium.pageobject.debug.NodeJsDebugConfig;
import org.eclipse.che.selenium.pageobject.intelligent.CommandsPalette;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

public class WildFlyUserStoryTest {
  private static final Logger LOG = LoggerFactory.getLogger(NodeJsUserStoryTest.class);
  private final String WORKSPACE = generate(WildFlyUserStoryTest.class.getSimpleName(), 4);
  private final String PROJECT = "wfswarm-rest-http";
  private final String PATH_TO_MAIN_PACKAGE =
      "wfswarm-rest-http/src/main/java/io/openshift/booster/";
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
  @Inject private HttpJsonRequestFactory   requestFactory;
  @Inject private Menu                     menu;
  @Inject private CodereadyDebuggerPanel   debugPanel;
  @Inject private NodeJsDebugConfig        debugConfig;
  @Inject private Events                   events;
  @Inject private NotificationsPopupPanel  notifications;
  @Inject private CodereadyFindUsageWidget findUsages;
  @Inject private TestProjectServiceClient projectServiceClient;
  @Inject private SeleniumWebDriver        seleniumWebDriver;
  @Inject private AssistantFindPanel       assistantFindPanel;
  @Inject private MavenPluginStatusBar     mavenPluginStatusBar;
  private         TestWorkspace            testWorkspace;

  @BeforeClass
  public void setUp() {
    dashboard.open();
  }

  @AfterClass
  public void tearDown() throws Exception {
    workspaceServiceClient.delete(WORKSPACE, defaultTestUser.getName());
  }

  @Test
  public void createJavaEAPWorkspaceWithProjectFromDashBoard() {
    createWsFromWildFlyStack();
  }

  @Test
  public void runAndCheckWildFlyApp()
      throws InterruptedException, ExecutionException, TimeoutException {

    runAndCheckHelloWorldApp();
    checkCodeValidation();
  }

  private void createWsFromWildFlyStack() {
    dashboard.selectWorkspacesItemOnDashboard();
    dashboard.waitToolbarTitleName("Workspaces");
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.typeWorkspaceName(WORKSPACE);
    newWorkspace.selectCodereadyStack(WILD_FLY_SWARM);
    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.addSampleToWorkspace(PROJECT);
    newWorkspace.clickOnCreateButtonAndOpenInIDE();
    seleniumWebDriverHelper.switchToIdeFrameAndWaitAvailability();
    projectExplorer.waitItem(PROJECT);
    events.clickEventLogBtn();
    events.waitExpectedMessage("Branch 'master' is checked out");
    consoles.clickOnProcessesButton();
    consoles.waitJDTLSProjectResolveFinishedMessage(PROJECT);
    testWorkspace = testWorkspaceProvider.getWorkspace(WORKSPACE, defaultTestUser);
  }

  private void runAndCheckHelloWorldApp()
      throws InterruptedException, ExecutionException, TimeoutException {
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick("wfswarm-rest-http:build");
    consoles.waitExpectedTextIntoConsole(BUILD_SUCCESS,240);
    commandsPalette.openCommandPalette();
    commandsPalette.startCommandByDoubleClick("wfswarm-rest-http:run");
    consoles.waitExpectedTextIntoConsole("Thorntail is Ready");
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

  private void checkCodeValidation() {
    String pathToFile = PATH_TO_MAIN_PACKAGE + "GreetingEndpoint.java";
    projectExplorer.quickRevealToItemWithJavaScript(pathToFile);
    projectExplorer.openItemByPath(pathToFile);
    editor.waitActive();
    mavenPluginStatusBar.waitClosingInfoPanel();
    editor.goToPosition(34, 55);
    editor.typeTextIntoEditor(ENTER.toString());
    editor.typeTextIntoEditor("suf");
    editor.launchAutocomplete();
    editor.waitTextIntoEditor("\"World\";\n        suffix");
    editor.waitMarkerInPosition(ERROR, 35);
    editor.goToPosition(35,15);
    editor.typeTextIntoEditor(".to");
    editor.launchAutocomplete();
    editor.selectItemIntoAutocompleteAndPerformDoubleClick("CharArray() : char[] ");
    editor.waitTextIntoEditor("suffix.toCharArray()");
    editor.typeTextIntoEditor(";");
    editor.waitAllMarkersInvisibility(ERROR);
  }


}
