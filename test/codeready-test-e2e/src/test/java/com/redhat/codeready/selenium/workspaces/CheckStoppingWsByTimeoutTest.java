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
package com.redhat.codeready.selenium.workspaces;

import static java.util.concurrent.TimeUnit.MILLISECONDS;
import static org.eclipse.che.api.core.model.workspace.WorkspaceStatus.STOPPED;
import static org.eclipse.che.selenium.core.utils.WaitUtils.sleepQuietly;
import static org.testng.Assert.assertEquals;

import com.google.inject.Inject;
import com.google.inject.name.Named;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyCreateWorkspaceHelper;
import org.eclipse.che.api.core.model.workspace.Workspace;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Devfile;
import org.eclipse.che.selenium.pageobject.theia.TheiaIde;
import org.openqa.selenium.By;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

public class CheckStoppingWsByTimeoutTest {

  @Inject private Dashboard dashboard;
  @Inject private TestWorkspaceServiceClient workspaceServiceClient;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private CodereadyCreateWorkspaceHelper codereadyCreateWorkspaceHelper;
  @Inject private TheiaIde theiaIde;
  @Inject private SeleniumWebDriverHelper seleniumWebDriverHelper;

  @Inject
  @Named("che.workspace_agent_dev_inactive_stop_timeout_ms")
  private int cheWorkspaceAgentDevInactiveStopTimeoutMilliseconds;

  @Inject
  @Named("che.workspace.activity_check_scheduler_period_s")
  private int cheWorkspaceActivityCheckSchedulerPeriodInSeconds;

  private String workspaceName;

  @BeforeClass
  public void setUp() throws Exception {
    dashboard.open();
    workspaceName =
        codereadyCreateWorkspaceHelper.createAndStartWorkspace(
            Devfile.JAVA_MAVEN, "vertx-health-checks");
  }

  @AfterClass
  public void tearDown() throws Exception {
    workspaceServiceClient.delete(workspaceName, defaultTestUser.getName());
  }

  @Test
  public void checkStoppingByApi() throws Exception {
    sleepQuietly(getCommonTimeoutInMilliSec(), MILLISECONDS);

    Workspace workspace =
        workspaceServiceClient.getByName(workspaceName, defaultTestUser.getName());
    assertEquals(workspace.getStatus(), STOPPED);
  }

  @Test(priority = 1)
  public void checkIdeStatusAfterStopping() {
    seleniumWebDriverHelper.waitVisibility(
        By.xpath("//div[@id='theia-statusBar']//div[@title='Cannot connect to backend.']"));
  }

  private int getCommonTimeoutInMilliSec() {
    return cheWorkspaceAgentDevInactiveStopTimeoutMilliseconds
        + cheWorkspaceActivityCheckSchedulerPeriodInSeconds * 1000;
  }
}
