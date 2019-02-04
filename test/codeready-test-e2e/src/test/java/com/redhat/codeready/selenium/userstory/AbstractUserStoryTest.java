/*
* Copyright (c) 2018 Red Hat, Inc.

* All rights reserved. This program and the accompanying materials
* are made available under the terms of the Eclipse Public License v1.0
* which accompanies this distribution, and is available at
* http://www.eclipse.org/legal/epl-v10.html
*
* Contributors:
*   Red Hat, Inc. - initial API and implementation
*/
package com.redhat.codeready.selenium.userstory;

import static org.eclipse.che.commons.lang.NameGenerator.generate;

import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.dashboard.CodeReadyCreateWorkspaceHelper;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import java.util.List;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/** @author Dmytro Nochevnov */
public abstract class AbstractUserStoryTest {
  protected final Logger LOG = LoggerFactory.getLogger(this.getClass());
  protected final String WORKSPACE = generate(this.getClass().getSimpleName(), 4);

  @Inject private Ide ide;
  @Inject private Dashboard dashboard;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private TestWorkspaceServiceClient workspaceServiceClient;
  @Inject private Consoles consoles;
  @Inject private CodeReadyCreateWorkspaceHelper codeReadyCreateWorkspaceHelper;
  @Inject private ProjectExplorer projectExplorer;

  // it is used to read workspace logs on test failure
  protected TestWorkspace testWorkspace;

  @BeforeClass
  public void setUp() {
    dashboard.open();
  }

  @AfterClass
  public void tearDown() throws Exception {
    workspaceServiceClient.delete(WORKSPACE, defaultTestUser.getName());
  }

  @Test
  public void createWorkspaceFromDashboard() throws Exception {
    testWorkspace =
        codeReadyCreateWorkspaceHelper.createWsFromStackWithTestProject(
            WORKSPACE, getStackName(), getProjects());

    ide.switchToIdeAndWaitWorkspaceIsReadyToUse();
    getProjects().forEach(projectExplorer::waitProjectInitialization);
  }

  protected abstract CodereadyNewWorkspace.CodereadyStacks getStackName();

  protected abstract List<String> getProjects();
}
