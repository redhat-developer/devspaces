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
package com.redhat.codeready.selenium.git;

import static org.eclipse.che.selenium.pageobject.dashboard.ProjectSourcePage.Sources.GITHUB;
import static org.testng.Assert.assertEquals;

import com.google.inject.Inject;
import com.google.inject.name.Named;
import com.redhat.codeready.selenium.pageobject.account.CodeReadyKeycloakFederatedIdentitiesPage;
import java.io.IOException;
import java.nio.file.Path;
import java.nio.file.Paths;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.TestGroup;
import org.eclipse.che.selenium.core.client.TestGitHubRepository;
import org.eclipse.che.selenium.core.client.TestGitHubServiceClient;
import org.eclipse.che.selenium.core.utils.WaitUtils;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace;
import org.eclipse.che.selenium.pageobject.dashboard.ProjectSourcePage;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/** @author Aleksandr Shmaraev */
@Test(groups = TestGroup.GITHUB)
public class AuthorizeOnGithubFromDashboardTest {
  private static final Logger LOG =
      LoggerFactory.getLogger(AuthorizeOnGithubFromDashboardTest.class);

  @Inject
  @Named("github.username")
  private String gitHubUsername;

  @Inject
  @Named("github.password")
  private String gitHubPassword;

  @Inject
  @Named("che.multiuser")
  private boolean isMultiuser;

  @Inject private Dashboard dashboard;
  @Inject private Workspaces workspaces;
  @Inject private NewWorkspace newWorkspace;
  @Inject private ProjectSourcePage projectSourcePage;
  @Inject private SeleniumWebDriver seleniumWebDriver;
  @Inject private SeleniumWebDriverHelper seleniumWebDriverHelper;
  @Inject private TestGitHubServiceClient gitHubClientService;
  @Inject private CodeReadyKeycloakFederatedIdentitiesPage codeReadyKeycloakFederatedIdentitiesPage;
  @Inject private TestGitHubRepository testRepo;
  @Inject private TestGitHubRepository testRepo2;

  @BeforeClass(groups = TestGroup.MULTIUSER)
  @AfterClass(groups = TestGroup.MULTIUSER)
  private void removeGitHubIdentity() {
    dashboard.open(); // to login
    codeReadyKeycloakFederatedIdentitiesPage.open();
    codeReadyKeycloakFederatedIdentitiesPage.ensureGithubIdentityIsAbsent();
    assertEquals(codeReadyKeycloakFederatedIdentitiesPage.getGitHubIdentityFieldValue(), "");
  }

  @BeforeClass
  private void revokeGithubOauthToken() {
    try {
      gitHubClientService.deleteAllGrants(gitHubUsername, gitHubPassword);
    } catch (Exception e) {
      LOG.warn("There was an error of revoking the github oauth token.", e);
    }
  }

  @Test
  public void checkAuthorizationOnGithubWhenLoadProjectList() throws IOException {
    // need to add projects if the github account doesn't have any repos that displayed in the list
    Path entryPath =
        Paths.get(getClass().getResource("/projects/default-spring-project").getPath());
    testRepo.addContent(entryPath);
    testRepo2.addContent(entryPath);

    dashboard.open();

    String ideWin = seleniumWebDriver.getWindowHandle();

    dashboard.waitDashboardToolbarTitle();
    dashboard.selectWorkspacesItemOnDashboard();
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.waitToolbar();

    projectSourcePage.clickOnAddOrImportProjectButton();
    projectSourcePage.selectSourceTab(GITHUB);
    projectSourcePage.clickOnConnectGithubAccountButton();
    WaitUtils.sleepQuietly(2);

    // login to github
    seleniumWebDriverHelper.switchToNextWindow(ideWin);
    projectSourcePage.waitAuthorizationPageOpened();
    projectSourcePage.typeLogin(gitHubUsername);
    projectSourcePage.typePassword(gitHubPassword);
    projectSourcePage.clickOnSignInButton();

    // authorize on github.com
    projectSourcePage.waitAuthorizeBtn();
    projectSourcePage.clickOnAuthorizeBtn();
    seleniumWebDriver.switchTo().window(ideWin);

    projectSourcePage.waitGithubProjectList();

    // check that repeat of getting of github projects list doesn't require authorization
    seleniumWebDriver.navigate().refresh();
    newWorkspace.waitToolbar();

    projectSourcePage.clickOnAddOrImportProjectButton();
    projectSourcePage.selectSourceTab(GITHUB);
    projectSourcePage.waitGithubProjectList();

    // check GitHub identity is present in Keycloak account management page
    if (isMultiuser) {
      codeReadyKeycloakFederatedIdentitiesPage.open();

      // set to lower case because it's normal behaviour (issue:
      // https://github.com/eclipse/che/issues/10138)
      assertEquals(
          codeReadyKeycloakFederatedIdentitiesPage.getGitHubIdentityFieldValue(),
          gitHubUsername.toLowerCase());
    }
  }
}
