/*
 * Copyright (c) 2019-2020 Red Hat, Inc.
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Contributors:
 *   Red Hat, Inc. - initial API and implementation
 */
package com.redhat.codeready.selenium.ocpoauth;

import static java.lang.String.format;
import static org.testng.AssertJUnit.assertEquals;
import static org.testng.AssertJUnit.assertTrue;

import com.google.inject.Inject;
import com.google.inject.name.Named;
import com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyCreateWorkspaceHelper;
import com.redhat.codeready.selenium.pageobject.site.CodereadyLoginPage;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.TestGroup;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.provider.TestDashboardUrlProvider;
import org.eclipse.che.selenium.core.user.TestUser;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Devfile;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.eclipse.che.selenium.pageobject.ocp.AuthorizeOpenShiftAccessPage;
import org.eclipse.che.selenium.pageobject.site.CheLoginPage;
import org.eclipse.che.selenium.pageobject.site.FirstBrokerProfilePage;
import org.testng.annotations.AfterClass;
import org.testng.annotations.Test;

@Test(groups = {TestGroup.OPENSHIFT, TestGroup.MULTIUSER})
public class LoginExistedUserWithOpenShiftOAuthTest {

  private static final String LOGIN_TO_CHE_WITH_OPENSHIFT_OAUTH_MESSAGE_TEMPLATE =
      "Authenticate to link your account with openshift";
  private static final String USER_ALREADY_EXISTS_ERROR_MESSAGE_TEMPLATE =
      "User with username %s already exists. How do you want to continue?";
  private static final String IDENTITY_PROVIDER_NAME = "htpasswd";

  private static final TestUser testUser = getTestUser();

  @Inject(optional = true)
  @Named("env.openshift.username")
  private String openShiftUsername;

  @Inject(optional = true)
  @Named("env.openshift.password")
  private String openShiftPassword;

  @Inject private CodereadyLoginPage codereadyLoginPage;
  @Inject private CodereadyOpenShiftLoginPage codereadyOpenShiftLoginPage;
  @Inject private FirstBrokerProfilePage firstBrokerProfilePage;
  @Inject private AuthorizeOpenShiftAccessPage authorizeOpenShiftAccessPage;
  @Inject private Dashboard dashboard;
  @Inject private Workspaces workspaces;
  @Inject private SeleniumWebDriver seleniumWebDriver;
  @Inject private TestDashboardUrlProvider testDashboardUrlProvider;
  @Inject private CodereadyCreateWorkspaceHelper codereadyCreateWorkspaceHelper;
  @Inject private TestWorkspaceServiceClient defaultUserWorkspaceServiceClient;
  @Inject private CheLoginPage cheLoginPage;

  private String workspaceName;

  @AfterClass
  private void removeTestWorkspace() throws Exception {
    defaultUserWorkspaceServiceClient.delete(workspaceName, testUser.getName());
  }

  @Test
  public void checkWorkspaceOSProjectCreationAndRemoval() {
    String expectedError = format(USER_ALREADY_EXISTS_ERROR_MESSAGE_TEMPLATE, testUser.getName());

    // go to login page of Codeready
    seleniumWebDriver.navigate().to(testDashboardUrlProvider.get());

    if (cheLoginPage.isOpened()) {
      cheLoginPage.loginWithOpenShiftOAuth();
    }

    if (codereadyOpenShiftLoginPage.isIdentityProviderLinkVisible(IDENTITY_PROVIDER_NAME)) {
      codereadyOpenShiftLoginPage.clickOnIdentityProviderLink(IDENTITY_PROVIDER_NAME);
    }

    codereadyOpenShiftLoginPage.login(openShiftUsername, openShiftPassword);

    // authorize ocp-client to access OpenShift account
    if (codereadyOpenShiftLoginPage.isApproveButtonVisible()) {
      authorizeOpenShiftAccessPage.waitOnOpen();
      authorizeOpenShiftAccessPage.allowPermissions();
    }

    firstBrokerProfilePage.submit(testUser);

    // apply OCP user information to Codeready user account
    assertEquals(firstBrokerProfilePage.getErrorAlert(), expectedError);
    firstBrokerProfilePage.addToExistingAccount();

    // login into Codeready again
    assertTrue(
        codereadyLoginPage
            .getInfoAlert()
            .contains(LOGIN_TO_CHE_WITH_OPENSHIFT_OAUTH_MESSAGE_TEMPLATE));
    codereadyLoginPage.loginWithPredefinedUsername(testUser.getPassword());

    workspaceName =
        codereadyCreateWorkspaceHelper.createAndStartWorkspace(
            Devfile.JAVA_MAVEN, "vertx-health-checks");

    // delete the created workspace on Dashboard
    seleniumWebDriver.navigate().to(testDashboardUrlProvider.get());
    dashboard.waitDashboardToolbarTitle();
    dashboard.selectWorkspacesItemOnDashboard();
    workspaces.selectAllWorkspacesByBulk();
    workspaces.clickOnDeleteWorkspacesBtn();
    workspaces.clickOnDeleteButtonInDialogWindow();
    workspaces.waitWorkspaceIsNotPresent(workspaceName);
  }

  private static TestUser getTestUser() {
    return new TestUser() {
      private final String name = "admin";
      private final String email = name + "@1.com";
      private final String password = "admin";

      @Override
      public String getEmail() {
        return email;
      }

      @Override
      public String getPassword() {
        return password;
      }

      @Override
      public String obtainAuthToken() {
        return null;
      }

      @Override
      public String getName() {
        return name;
      }

      @Override
      public String getId() {
        return null;
      }

      @Override
      public void delete() {}
    };
  }
}
