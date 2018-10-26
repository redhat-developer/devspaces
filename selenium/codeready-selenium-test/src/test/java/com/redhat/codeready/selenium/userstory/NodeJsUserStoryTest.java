package com.redhat.codeready.selenium.userstory;

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.NODE;
import static org.eclipse.che.commons.lang.NameGenerator.generate;

import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.RhDebuggerPanel;
import com.redhat.codeready.selenium.pageobject.RhEditor;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import com.redhat.codeready.selenium.pageobject.dashboard.RhFindUsagesWidget;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import javax.ws.rs.HttpMethod;
import org.apache.http.HttpStatus;
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

public class NodeJsUserStoryTest {
  private static final Logger LOG = LoggerFactory.getLogger(NodeJsUserStoryTest.class);
  private final String WORKSPACE = generate("NodeJsUserStoryTest", 4);
  private final String PROJECT = "web-nodejs-simple";
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
  @Inject private RhEditor editor;
  @Inject private HttpJsonRequestFactory requestFactory;
  @Inject private Menu menu;
  @Inject private RhDebuggerPanel debugPanel;
  @Inject private JavaDebugConfig debugConfig;
  @Inject private Events events;
  @Inject private NotificationsPopupPanel notifications;
  @Inject private RhFindUsagesWidget findUsages;
  @Inject private TestProjectServiceClient projectServiceClient;
  @Inject private SeleniumWebDriver seleniumWebDriver;
  private TestWorkspace testWorkspace;

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
    createWsFromNodeJsStackWithTestProject(PROJECT);
  }

  @Test
  public void runAndCheckNodeJsApp() throws Exception {
    runAndCheckHelloWorldApp();
  }

  private void createWsFromNodeJsStackWithTestProject(String example) {
    dashboard.selectWorkspacesItemOnDashboard();
    dashboard.waitToolbarTitleName("Workspaces");
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.typeWorkspaceName(WORKSPACE);
    newWorkspace.selectCodereadyStack(NODE);
    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.addSampleToWorkspace(example);
    newWorkspace.clickOnCreateButtonAndOpenInIDE();
    seleniumWebDriverHelper.switchToIdeFrameAndWaitAvailability();
    projectExplorer.waitItem(example);
    events.clickEventLogBtn();
    events.waitExpectedMessage("Branch 'master' is checked out");
    testWorkspace = testWorkspaceProvider.getWorkspace(WORKSPACE, defaultTestUser);
  }

  private void runAndCheckHelloWorldApp()
          throws InterruptedException, ExecutionException, TimeoutException, IOException {
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
        TestTimeoutsConstants.LOAD_PAGE_TIMEOUT_SEC,
        TestTimeoutsConstants.MULTIPLE,
        TimeUnit.SECONDS);
    consoles.waitExpectedTextIntoConsole("Example app listening on port 3000!");
  }

  private boolean isTestApplicationAvailable(String appUrl) throws IOException {
    HttpURLConnection httpURLConnection = (HttpURLConnection) new URL(appUrl).openConnection();
    httpURLConnection.setRequestMethod(HttpMethod.GET);
    return httpURLConnection.getResponseCode() == HttpStatus.SC_OK;
  }

  private void checkCodeValidation(){

  }

  private void checkHovering(){

  }

  private void checkRenaming(){

  }

  private void checkSy

}
