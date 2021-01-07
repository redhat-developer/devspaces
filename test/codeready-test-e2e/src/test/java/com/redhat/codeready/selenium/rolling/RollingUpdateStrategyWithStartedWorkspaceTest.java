/*
 * Copyright (c) 2018-2021 Red Hat, Inc.
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Contributors:
 *   Red Hat, Inc. - initial API and implementation
 */
package com.redhat.codeready.selenium.rolling;

import static org.testng.Assert.assertTrue;

import com.google.inject.Inject;
import com.redhat.codeready.selenium.core.executor.hotupdate.CodeReadyHotUpdateUtil;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyCreateWorkspaceHelper;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyDashboard;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.utils.WaitUtils;
import org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Devfile;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.eclipse.che.selenium.pageobject.theia.TheiaIde;
import org.eclipse.che.selenium.pageobject.theia.TheiaProjectTree;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/** @author Katerina Kanova */
public class RollingUpdateStrategyWithStartedWorkspaceTest {
  private static final String PROJECT_NAME = "vertx-health-checks";

  @Inject private CodereadyDashboard dashboard;
  @Inject private Workspaces workspaces;
  @Inject private CodeReadyHotUpdateUtil codeReadyHotUpdateUtil;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private TestWorkspaceServiceClient workspaceServiceClient;
  @Inject private CodereadyCreateWorkspaceHelper codereadyCreateWorkspaceHelper;
  @Inject private TheiaIde theiaIde;
  @Inject private TheiaProjectTree theiaProjectTree;

  private String workspaceName;

  @BeforeClass
  public void setUp() throws Exception {
    dashboard.open();
    workspaceName =
        codereadyCreateWorkspaceHelper.createAndStartWorkspace(Devfile.JAVA_MAVEN, PROJECT_NAME);
  }

  @AfterClass
  public void tearDown() throws Exception {
    workspaceServiceClient.delete(workspaceName, defaultTestUser.getName());
  }

  @Test
  public void startStopWorkspaceFunctionsShouldBeAvailableDuringRollingUpdate() throws Exception {
    theiaProjectTree.waitFilesTab();
    theiaProjectTree.clickOnFilesTab();
    theiaProjectTree.waitProjectAreaOpened();
    theiaIde.waitAllNotificationsClosed();

    dashboard.open();
    dashboard.waitDashboardToolbarTitle();
    dashboard.selectWorkspacesItemOnDashboard();
    dashboard.waitToolbarTitleName("Workspaces");

    // check existing of expected workspace and its status
    workspaces.waitPageLoading();
    workspaces.waitWorkspaceIsPresent(workspaceName);
    workspaces.waitWorkspaceStatus(workspaceName, Workspaces.Status.RUNNING);

    codeReadyHotUpdateUtil.executeMasterPodUpdateCommand();

    assertTrue(
        codeReadyHotUpdateUtil
            .getRolloutStatus()
            .contains("deployment \"codeready\" successfully rolled out"));
    WaitUtils.sleepQuietly(60);

    workspaces.waitWorkspaceIsPresent(workspaceName);
    workspaces.waitWorkspaceStatus(workspaceName, Workspaces.Status.RUNNING);
  }
}
