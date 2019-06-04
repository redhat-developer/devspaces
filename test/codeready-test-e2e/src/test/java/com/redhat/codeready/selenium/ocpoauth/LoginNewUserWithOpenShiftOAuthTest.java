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
import static org.eclipse.che.commons.lang.NameGenerator.generate;

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
import org.eclipse.che.selenium.pageobject.dashboard.CreateWorkspaceHelper;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.eclipse.che.selenium.pageobject.ocp.AuthorizeOpenShiftAccessPage;
import org.eclipse.che.selenium.pageobject.ocp.OpenShiftProjectCatalogPage;
import org.eclipse.che.selenium.pageobject.site.CheLoginPage;
import org.eclipse.che.selenium.pageobject.site.FirstBrokerProfilePage;
import org.testng.annotations.AfterClass;
import org.testng.annotations.Test;

@Test(groups = {TestGroup.OPENSHIFT, TestGroup.MULTIUSER})
public class LoginNewUserWithOpenShiftOAuthTest {

  private static final String WORKSPACE_NAME = generate("workspace", 4);
  private static final String PROJECT = "kitchensink-example";

  private TestWorkspace testWorkspace;
  private static final TestUser testUser = getTestUser();

  @Inject(optional = true)
  @Named("env.openshift.regular.username")
  private String openShiftUsername;

  @Inject(optional = true)
  @Named("env.openshift.regular.password")
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
  @Inject private CreateWorkspaceHelper createWorkspaceHelper;
  @Inject private CodeReadyCreateWorkspaceHelper codeReadyCreateWorkspaceHelper;

  @AfterClass
  private void removeTestWorkspace() throws Exception {
    testWorkspace.delete();
  }

  @Test
  public void checkWorkspaceOSProjectCreationAndRemoval() throws Exception {
    // go to login page of Codeready
    seleniumWebDriver.navigate().to(testDashboardUrlProvider.get());

    cheLoginPage.loginWithOpenShiftOAuth();
    codereadyOpenShiftLoginPage.login(openShiftUsername, openShiftPassword);

    // authorize ocp-client to access OpenShift account
    if (codereadyOpenShiftLoginPage.isApproveButtonVisible()) {
      authorizeOpenShiftAccessPage.waitOnOpen();
      authorizeOpenShiftAccessPage.allowPermissions();
    }

    // fill first broker profile page
    firstBrokerProfilePage.submit(testUser);

    // create and open workspace
    testWorkspace =
        codeReadyCreateWorkspaceHelper.createWsFromStackWithTestProject(
            WORKSPACE_NAME, JAVA_DEFAULT, ImmutableList.of(PROJECT));

    // switch to the Codeready IDE and wait until workspace is ready to use
    seleniumWebDriverHelper.switchToIdeFrameAndWaitAvailability();
    toastLoader.waitToastLoaderAndClickStartButton();
    ide.waitOpenedWorkspaceIsReadyToUse();

    // go to OCP and check if there is a project with name equals to test workspace id
    openShiftProjectCatalogPage.open();
    codereadyOpenShiftLoginPage.login(openShiftUsername, openShiftPassword);
    codereadyOpenShiftLoginPage.waitOnClose();
    openShiftProjectCatalogPage.waitProject("workspace");

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
    openShiftProjectCatalogPage.waitProjectAbsence("workspace");
  }

  private static TestUser getTestUser() {
    return new TestUser() {
      private final String name = "crw";
      private final String email = name + "@1.com";
      private final String password = "crw";

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
