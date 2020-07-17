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

import com.google.inject.Inject;
import com.google.inject.name.Named;
import com.redhat.codeready.selenium.pageobject.CodereadyOpenShiftLoginPage;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyCreateWorkspaceHelper;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.TestGroup;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.provider.TestDashboardUrlProvider;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Devfile;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.eclipse.che.selenium.pageobject.ocp.AuthorizeOpenShiftAccessPage;
import org.eclipse.che.selenium.pageobject.site.CheLoginPage;
import org.testng.annotations.AfterClass;
import org.testng.annotations.Test;

@Test(groups = {TestGroup.OPENSHIFT, TestGroup.MULTIUSER})
public class LoginNewUserWithOpenShiftOAuthTest {

  private static final String IDENTITY_PROVIDER_NAME = "htpasswd";

  @Inject(optional = true)
  @Named("env.openshift.regular.username")
  private String openShiftUsername;

  @Inject(optional = true)
  @Named("env.openshift.regular.password")
  private String openShiftPassword;

  @Inject(optional = true)
  @Named("env.openshift.regular.email")
  private String openShiftEmail;

  @Inject private CodereadyOpenShiftLoginPage codereadyOpenShiftLoginPage;
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
    defaultUserWorkspaceServiceClient.delete(workspaceName, openShiftUsername);
  }

  @Test
  public void checkWorkspaceOSProjectCreationAndRemoval() throws Exception {
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

    codereadyOpenShiftLoginPage.submit(openShiftUsername, openShiftEmail);

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
}
