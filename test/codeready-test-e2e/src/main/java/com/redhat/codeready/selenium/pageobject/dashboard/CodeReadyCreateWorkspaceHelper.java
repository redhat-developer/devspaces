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
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
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

  private static final Map<String, String> REGISTRY_ADDRESS_REPLACEMENT =
      new LinkedHashMap<String, String>() {
        {
          put(
              "registry.access.redhat.com/codeready-workspaces-beta/stacks-java-rhel8",
              "quay.io/crw/stacks-java-rhel8:1.0-16");
          put(
              "registry.access.redhat.com/codeready-workspaces/stacks-cpp",
              "quay.io/crw/stacks-cpp:1.1-7");
          put(
              "registry.access.redhat.com/codeready-workspaces/stacks-dotnet",
              "quay.io/crw/stacks-dotnet:1.1-4");
          put(
              "registry.access.redhat.com/codeready-workspaces/stacks-golang",
              "quay.io/crw/stacks-golang:1.0-14");
          put(
              "registry.access.redhat.com/codeready-workspaces/stacks-java",
              "quay.io/crw/stacks-java:1.1-6");
          put(
              "registry.access.redhat.com/codeready-workspaces/stacks-node",
              "quay.io/crw/stacks-node:1.0-16");
          put(
              "registry.access.redhat.com/codeready-workspaces/stacks-php",
              "quay.io/crw/stacks-php:1.0-16");
          put(
              "registry.access.redhat.com/codeready-workspaces/stacks-python",
              "quay.io/crw/stacks-python:1.0-14");
        }
      };

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

    String machineName = "dev-machine";
    String successNotificationText = "Workspace updated.";

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

    if (REGISTRY_ADDRESS_REPLACEMENT.isEmpty()) {
      codereadyNewWorkspace.clickOnCreateButtonAndOpenInIDE();

    } else {
      newWorkspace.clickOnCreateButtonAndEditWorkspace();
      fixStackImageAddress(workspaceName, machineName, successNotificationText);
      codereadyNewWorkspace.clickOnOpenInIDEButton();
    }

    return testWorkspaceProvider.getWorkspace(workspaceName, defaultTestUser);
  }

  private void fixStackImageAddress(
      String workspaceName, String machineName, String successNotificationText) {
    // create workspace to edit
    workspaceDetails.waitToolbarTitleName(workspaceName);
    workspaceDetails.selectTabInWorkspaceMenu(MACHINES);
    workspaceDetailsMachines.waitMachineListItem(machineName);

    // edit recipe
    workspaceDetailsMachines.clickOnEditButton(machineName);
    editMachineForm.waitForm();

    JavascriptExecutor js = (JavascriptExecutor) seleniumWebDriver;
    String currentStackImageAddress =
        js.executeScript(
                "return document.querySelector('.edit-machine-form .CodeMirror').CodeMirror.getValue();")
            .toString();

    boolean isValueFound = false;

    for (Map.Entry<String, String> entry : REGISTRY_ADDRESS_REPLACEMENT.entrySet()) {
      String oldAddressPrefix = entry.getKey();
      String newAddressPrefix = entry.getValue();

      if (currentStackImageAddress != null
          && (currentStackImageAddress.startsWith(oldAddressPrefix))) {
        String newStackImageAddress =
            currentStackImageAddress.replace(oldAddressPrefix, newAddressPrefix);
        js.executeScript(
            String.format(
                "document.querySelector('.edit-machine-form .CodeMirror').CodeMirror.setValue('%s')",
                newStackImageAddress));

        // save changes
        editMachineForm.waitRecipeText(newStackImageAddress);
        editMachineForm.waitSaveButtonEnabling();
        editMachineForm.clickOnSaveButton();
        editMachineForm.waitFormInvisibility();
        workspaceDetailsMachines.waitImageNameInMachineListItem(machineName, newStackImageAddress);
        workspaceDetails.waitAllEnabled(SAVE_BUTTON);
        workspaceDetails.clickOnSaveChangesBtn();
        workspaceDetailsMachines.waitNotificationMessage(successNotificationText);

        isValueFound = true;
        break;
      }
    }

    if (!isValueFound) {
      editMachineForm.clickOnCloseIcon();
      editMachineForm.waitFormInvisibility();
    }
  }
}
