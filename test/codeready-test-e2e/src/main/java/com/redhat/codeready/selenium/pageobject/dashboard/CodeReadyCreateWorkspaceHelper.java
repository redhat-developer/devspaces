/*
 * Copyright (c) 2019 Red Hat, Inc.
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Contributors:
 *   Red Hat, Inc. - initial API and implementation
 */
package com.redhat.codeready.selenium.pageobject.dashboard;

import static java.lang.String.format;
import static org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceDetails.ActionButton.SAVE_BUTTON;
import static org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceDetails.WorkspaceDetailsTab.MACHINES;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import com.redhat.codeready.selenium.core.provider.TestStackAddressReplacementProvider;
import java.util.List;
import java.util.Optional;
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
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** @author Aleksandr Shmaraiev */
@Singleton
public class CodeReadyCreateWorkspaceHelper {
  private static final Logger LOG = LoggerFactory.getLogger(CodeReadyCreateWorkspaceHelper.class);

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
  @Inject private TestStackAddressReplacementProvider testStackAddressReplacementProvider;

  public TestWorkspace createWsFromStackWithTestProject(
      String workspaceName,
      CodereadyNewWorkspace.CodereadyStacks stackName,
      List<String> projectNames) {

    String machineName = "dev-machine";
    String successNotificationText = "Workspace updated.";

    // select stack on workspace dashboard
    dashboard.waitDashboardToolbarTitle();
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

    if (testStackAddressReplacementProvider.get().isEmpty()) {
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
    String currentStackAddress =
        js.executeScript(
                "return document.querySelector('.edit-machine-form .CodeMirror').CodeMirror.getValue();")
            .toString();

    Optional<String> stackAddressReplacement =
        testStackAddressReplacementProvider.get(currentStackAddress);
    if (stackAddressReplacement.isPresent()) {
      String newStackAddress = stackAddressReplacement.get();
      js.executeScript(
          format(
              "document.querySelector('.edit-machine-form .CodeMirror').CodeMirror.setValue('%s')",
              newStackAddress));

      // save changes
      editMachineForm.waitRecipeText(newStackAddress);
      editMachineForm.waitSaveButtonEnabling();
      editMachineForm.clickOnSaveButton();
      editMachineForm.waitFormInvisibility();
      workspaceDetailsMachines.waitImageNameInMachineListItem(machineName, newStackAddress);
      workspaceDetails.waitAllEnabled(SAVE_BUTTON);
      workspaceDetails.clickOnSaveChangesBtn();
      workspaceDetailsMachines.waitNotificationMessage(successNotificationText);

      LOG.info(
          format(
              "Stack address '%s' has been replaced by '%s' in test workspace with name '%s'.",
              currentStackAddress, newStackAddress, workspaceName));

      return;
    }

    editMachineForm.clickOnCloseIcon();
    editMachineForm.waitFormInvisibility();
  }
}
