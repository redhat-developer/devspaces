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
package com.redhat.codeready.selenium.pageobject.dashboard;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import java.util.List;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.core.workspace.TestWorkspaceProvider;
import org.eclipse.che.selenium.pageobject.dashboard.AddOrImportForm;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace;
import org.eclipse.che.selenium.pageobject.dashboard.ProjectSourcePage;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.EditMachineForm;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceDetails;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceDetailsMachines;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;

/** @author Aleksandr Shmaraiev */
@Singleton
public class CodeReadyCreateWorkspaceHelper {

  @Inject private Dashboard dashboard;
  @Inject private Workspaces workspaces;
  @Inject private AddOrImportForm addOrImportForm;
  @Inject private WorkspaceDetails workspaceDetails;
  @Inject private WorkspaceDetailsMachines workspaceDetailsMachines;
  @Inject private EditMachineForm editMachineForm;
  @Inject private NewWorkspace newWorkspace;
  @Inject private ProjectSourcePage projectSourcePage;
  @Inject private CodereadyNewWorkspace codereadyNewWorkspace;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private TestWorkspaceProvider testWorkspaceProvider;
  @Inject private SeleniumWebDriver seleniumWebDriver;

  public TestWorkspace createWsFromStackWithTestProject(
      String workspaceName,
      CodereadyNewWorkspace.CodereadyStacks stackName,
      List<String> projectNames) {

    // select stack on workspace dashboard
    dashboard.selectWorkspacesItemOnDashboard();
    dashboard.waitToolbarTitleName("Workspaces");
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.typeWorkspaceName(workspaceName);
    codereadyNewWorkspace.selectCodereadyStack(stackName);

    // select sample projects
    if (projectNames != null && !projectNames.isEmpty()) {
      addOrImportForm.clickOnAddOrImportProjectButton();
      projectNames.forEach(projectSourcePage::selectSample);
      projectSourcePage.clickOnAddProjectButton();
    }

    // create workspace to edit
    newWorkspace.clickOnCreateButtonAndOpenInIDE();
    return testWorkspaceProvider.getWorkspace(workspaceName, defaultTestUser);
  }
}
