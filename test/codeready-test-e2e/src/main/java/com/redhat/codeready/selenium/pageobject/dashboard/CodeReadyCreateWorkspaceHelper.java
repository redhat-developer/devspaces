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

import static org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceDetails.ActionButton.SAVE_BUTTON;
import static org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceDetails.WorkspaceDetailsTab.MACHINES;

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
import org.openqa.selenium.JavascriptExecutor;

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
      String addressStackImage,
      List<String> projectNames) {

    String machineName = "dev-machine";
    String successNotificationText = "Workspace updated.";

    // select stack on workspace dashboard
    dashboard.selectWorkspacesItemOnDashboard();
    dashboard.waitToolbarTitleName("Workspaces");
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.typeWorkspaceName(workspaceName);
    codereadyNewWorkspace.selectCodereadyStack(stackName);

    // select sample project
    addOrImportForm.clickOnAddOrImportProjectButton();
    projectNames.forEach(projectSourcePage::selectSample);
    projectSourcePage.clickOnAddProjectButton();

    // create workspace to edit
    newWorkspace.clickOnCreateButtonAndEditWorkspace();
    workspaceDetails.waitToolbarTitleName(workspaceName);
    workspaceDetails.selectTabInWorkspaceMenu(MACHINES);
    workspaceDetailsMachines.waitMachineListItem(machineName);

    // edit recipe
    workspaceDetailsMachines.clickOnEditButton(machineName);
    editMachineForm.waitForm();

    JavascriptExecutor js = (JavascriptExecutor) seleniumWebDriver;
    js.executeScript(
        String.format(
            "document.querySelector('.edit-machine-form .CodeMirror').CodeMirror.setValue('%s')",
            addressStackImage));

    // save changes
    editMachineForm.waitRecipeText(addressStackImage);
    editMachineForm.waitSaveButtonEnabling();
    editMachineForm.clickOnSaveButton();
    editMachineForm.waitFormInvisibility();
    workspaceDetailsMachines.waitImageNameInMachineListItem(machineName, addressStackImage);
    workspaceDetails.waitAllEnabled(SAVE_BUTTON);
    workspaceDetails.clickOnSaveChangesBtn();
    workspaceDetailsMachines.waitNotificationMessage(successNotificationText);

    codereadyNewWorkspace.clickOnOpenInIDEButton();

    return testWorkspaceProvider.getWorkspace(workspaceName, defaultTestUser);
  }
}
