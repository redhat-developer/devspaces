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
package com.redhat.codeready.selenium.ocpoauth;

import static com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks.JAVA_DEFAULT;
import static java.lang.String.format;
import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.testng.Assert.fail;
import static org.testng.AssertJUnit.assertEquals;

import com.google.common.collect.ImmutableList;
import com.google.inject.Inject;
import com.google.inject.name.Named;
import com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage;
import com.redhat.codeready.selenium.pageobject.dashboard.CodeReadyCreateWorkspaceHelper;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.TestGroup;
import org.eclipse.che.selenium.core.provider.TestDashboardUrlProvider;
import org.eclipse.che.selenium.core.user.TestUser;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.ToastLoader;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.eclipse.che.selenium.pageobject.ocp.AuthorizeOpenShiftAccessPage;
import org.eclipse.che.selenium.pageobject.ocp.OpenShiftProjectCatalogPage;
import org.eclipse.che.selenium.pageobject.site.CheLoginPage;
import org.eclipse.che.selenium.pageobject.site.FirstBrokerProfilePage;
import org.openqa.selenium.TimeoutException;
import org.testng.annotations.AfterClass;
import org.testng.annotations.Test;

@Test(groups = {TestGroup.OPENSHIFT, TestGroup.MULTIUSER})
public class LoginExistedUserWithOpenShiftOAuthTest {

  private static final String WORKSPACE_NAME = generate("workspace", 4);
  private static final String PROJECT = "kitchensink-example";
  private static final String LOGIN_TO_CHE_WITH_OPENSHIFT_OAUTH_MESSAGE_TEMPLATE =
      "Authenticate as %s to link your account with openshift-v3";
  private static final String USER_ALREADY_EXISTS_ERROR_MESSAGE_TEMPLATE =
      "User with username %s already exists. How do you want to continue?";
  private static final String IDENTITY_PROVIDER_NAME = "htpasswd_provider";

  private TestWorkspace testWorkspace;
  private static final TestUser testUser = getTestUser();

  @Inject(optional = true)
  @Named("env.openshift.username")
  private String openShiftUsername;

  @Inject(optional = true)
  @Named("env.openshift.password")
  private String openShiftPassword;

  @Inject private CheLoginPage cheLoginPage;
  @Inject private CodereadyOpenShiftLoginPage codereadyOpenShiftLoginPage;
  @Inject private FirstBrokerProfilePage firstBrokerProfilePage;
  @Inject private AuthorizeOpenShiftAccessPage authorizeOpenShiftAccessPage;
  @Inject private Dashboard dashboard;
  @Inject private Workspaces workspaces;
  @Inject private ToastLoader toastLoader;
  @Inject private Ide ide;
  @Inject private SeleniumWebDriverHelper seleniumWebDriverHelper;
  @Inject private OpenShiftProjectCatalogPage openShiftProjectCatalogPage;
  @Inject private SeleniumWebDriver seleniumWebDriver;
  @Inject private TestDashboardUrlProvider testDashboardUrlProvider;
  @Inject private CodeReadyCreateWorkspaceHelper codeReadyCreateWorkspaceHelper;

  @AfterClass
  private void removeTestWorkspace() throws Exception {
    testWorkspace.delete();
  }

  @Test
  public void checkWorkspaceOSProjectCreationAndRemoval() {
    String expectedError = format(USER_ALREADY_EXISTS_ERROR_MESSAGE_TEMPLATE, testUser.getName());

    // go to login page of Codeready
    seleniumWebDriver.navigate().to(testDashboardUrlProvider.get());

    cheLoginPage.loginWithOpenShiftOAuth();
    if (codereadyOpenShiftLoginPage.isIdentityProviderLinkVisible(IDENTITY_PROVIDER_NAME)) {
      codereadyOpenShiftLoginPage.clickOnIdentityProviderLink(IDENTITY_PROVIDER_NAME);
    }
    codereadyOpenShiftLoginPage.login(openShiftUsername, openShiftPassword);

    // authorize ocp-client to access OpenShift account
    if (codereadyOpenShiftLoginPage.isApproveButtonVisible()) {
      authorizeOpenShiftAccessPage.waitOnOpen();
      authorizeOpenShiftAccessPage.allowPermissions();
    }

    // fill profile page
    try {
      firstBrokerProfilePage.submit(testUser);
    } catch (TimeoutException ex) {
      // remove try-catch block after issue has been resolved
      fail("Known permanent OCP4.x failure https://issues.jboss.org/browse/CRW-202");
    }

    // apply OCP user information to Codeready user account
    assertEquals(firstBrokerProfilePage.getErrorAlert(), expectedError);
    firstBrokerProfilePage.addToExistingAccount();

    // login into Codeready again
    String expectedInfo =
        format(LOGIN_TO_CHE_WITH_OPENSHIFT_OAUTH_MESSAGE_TEMPLATE, testUser.getName());
    assertEquals(cheLoginPage.getInfoAlert(), expectedInfo);
    cheLoginPage.loginWithPredefinedUsername(testUser.getPassword());

    // create and open workspace
    testWorkspace =
        codeReadyCreateWorkspaceHelper.createWsFromStackWithTestProject(
            WORKSPACE_NAME, JAVA_DEFAULT, ImmutableList.of(PROJECT));

    // switch to the Codeready IDE and wait until workspace is ready to use
    seleniumWebDriverHelper.switchToIdeFrameAndWaitAvailability();
    toastLoader.waitToastLoaderAndClickStartButton();
    ide.waitOpenedWorkspaceIsReadyToUse();

    // delete the created workspace on Dashboard
    seleniumWebDriver.navigate().to(testDashboardUrlProvider.get());
    dashboard.waitDashboardToolbarTitle();
    dashboard.selectWorkspacesItemOnDashboard();
    workspaces.selectAllWorkspacesByBulk();
    workspaces.clickOnDeleteWorkspacesBtn();
    workspaces.clickOnDeleteButtonInDialogWindow();
    workspaces.waitWorkspaceIsNotPresent(WORKSPACE_NAME);

    // go to OCP and check that project is not exist
    openShiftProjectCatalogPage.open();
    codereadyOpenShiftLoginPage.login(openShiftUsername, openShiftPassword);
    openShiftProjectCatalogPage.waitProjectAbsence("workspace");
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
