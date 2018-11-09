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
package com.redhat.codeready.selenium.dashboard.workspaces;

import static org.eclipse.che.api.core.model.workspace.WorkspaceStatus.RUNNING;
import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.testng.Assert.assertEquals;

import com.google.common.collect.ImmutableMap;
import com.google.inject.Inject;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.core.workspace.TestWorkspaceProvider;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.dashboard.AddOrImportForm;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace;
import org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Stack;
import org.eclipse.che.selenium.pageobject.dashboard.ProjectOptions;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceOverview;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.BeforeMethod;
import org.testng.annotations.Test;

/** @author Ihor Okhrimenko */
public class AddOrImportProjectFormTest {

  private static final String NAME_WITH_MAX_AVAILABLE_LENGTH = generate("name", 124);
  private static final String WORKSPACE_NAME = "test-workspace";
  private static final String TEST_JAVA_WORKSPACE_NAME = "test-java-workspace";
  private static final String TEST_JAVA_WORKSPACE_NAME_EDIT = generate("test-java-workspace", 4);
  private static final String NAME_WITH_SPECIAL_CHARACTERS = "@#$%^&*";
  private static final String KITCHENSINCK_EXAMPLE = "kitchensink-example";
  private static final String EXPECTED_KITCHENSINC_REPOSITORY_URL =
      "https://github.com/openshift-quickstart/kitchensink-example.git";
  private static final String RENAMED_KITCHENSINK_SAMPLE_NAME = "kitchensink";
  private static final String EXPECTED_CONSOLE_REPOSITORY_URL =
      "https://github.com/openshift-quickstart/kitchensink-example.git";
  private static final String BLANK_FORM_DESCRIPTION = "example of description";
  private static final String CUSTOM_BLANK_PROJECT_NAME = "blank-project";
  private static final String BLANK_PROJECT_NAME = "blank";
  private static final String BLANK_DEFAULT_URL = "https://github.com/che-samples/blank";
  private static final ImmutableMap<String, String> EXPECTED_SAMPLES_WITH_DESCRIPTIONS =
      ImmutableMap.of(KITCHENSINCK_EXAMPLE, "This is the kitchensink JBoss quickstart app");

  @Inject private Dashboard dashboard;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private Workspaces workspaces;
  @Inject private NewWorkspace newWorkspace;
  @Inject private TestWorkspaceServiceClient testWorkspaceServiceClient;
  @Inject private SeleniumWebDriverHelper seleniumWebDriverHelper;
  @Inject private SeleniumWebDriver seleniumWebDriver;
  @Inject private WorkspaceOverview workspaceOverview;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private ProjectOptions projectOptions;
  @Inject private AddOrImportForm addOrImportForm;
  @Inject private TestWorkspaceProvider testWorkspaceProvider;

  // it is used to read workspace logs on test failure
  private TestWorkspace testWorkspace;

  @BeforeClass
  public void setup() {
    dashboard.open();
  }

  @AfterClass
  public void cleanup() throws Exception {
    testWorkspaceServiceClient.delete(WORKSPACE_NAME, defaultTestUser.getName());
    testWorkspaceServiceClient.delete(TEST_JAVA_WORKSPACE_NAME, defaultTestUser.getName());
    testWorkspaceServiceClient.delete(TEST_JAVA_WORKSPACE_NAME_EDIT, defaultTestUser.getName());
  }

  @BeforeMethod
  public void prepareToTestMethod() {
    dashboard.waitDashboardToolbarTitle();
    dashboard.selectWorkspacesItemOnDashboard();
    workspaces.waitToolbarTitleName();
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.waitPageLoad();
  }

  @Test
  public void checkOfCheckboxes() {
    // preparing
    newWorkspace.waitPageLoad();
    newWorkspace.selectStack(Stack.JAVA);
    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.waitAddOrImportFormOpened();
    addOrImportForm.waitSamplesButtonSelected();
    addOrImportForm.waitSamplesWithDescriptions(EXPECTED_SAMPLES_WITH_DESCRIPTIONS);
    waitAllCheckboxesDisabled();
    addOrImportForm.waitCancelButtonDisabled();
    addOrImportForm.waitAddButtonDisabled();

    // click on single disabled checkbox
    addOrImportForm.clickOnSampleCheckbox(KITCHENSINCK_EXAMPLE);
    addOrImportForm.waitSampleCheckboxEnabled(KITCHENSINCK_EXAMPLE);
    addOrImportForm.waitCancelButtonEnabled();
    addOrImportForm.waitAddButtonEnabled();

    // unselect checkbox by "Cancel" button
    addOrImportForm.clickOnCancelButton();
    addOrImportForm.waitSampleCheckboxDisabled(KITCHENSINCK_EXAMPLE);

    // select and unselect single checkbox by clicking on it
    addOrImportForm.clickOnSampleCheckbox(KITCHENSINCK_EXAMPLE);
    addOrImportForm.waitSampleCheckboxEnabled(KITCHENSINCK_EXAMPLE);
    addOrImportForm.waitCancelButtonEnabled();
    addOrImportForm.waitAddButtonEnabled();

    addOrImportForm.clickOnSampleCheckbox(KITCHENSINCK_EXAMPLE);
    addOrImportForm.waitSampleCheckboxDisabled(KITCHENSINCK_EXAMPLE);
    addOrImportForm.waitCancelButtonDisabled();
    addOrImportForm.waitAddButtonDisabled();

    // unselect multiple checkboxes by "Cancel" button
    clickOnEachCheckbox();
    waitAllCheckboxesEnabled();
    addOrImportForm.waitCancelButtonEnabled();
    addOrImportForm.waitAddButtonEnabled();

    addOrImportForm.clickOnCancelButton();
    waitAllCheckboxesDisabled();
    addOrImportForm.waitCancelButtonDisabled();
    addOrImportForm.waitAddButtonDisabled();
  }

  @Test(priority = 1)
  public void checkProjectSamples() {
    // preparing
    newWorkspace.waitPageLoad();
    newWorkspace.selectStack(Stack.JAVA);
    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.waitAddOrImportFormOpened();
    addOrImportForm.waitSamplesButtonSelected();

    // add single sample to workspace
    addOrImportForm.clickOnSampleCheckbox(KITCHENSINCK_EXAMPLE);
    addOrImportForm.waitSampleCheckboxEnabled(KITCHENSINCK_EXAMPLE);
    addOrImportForm.waitCancelButtonEnabled();
    addOrImportForm.waitAddButtonEnabled();
    addOrImportForm.clickOnAddButton();
    checkProjectTabAppearanceAndFields(
        KITCHENSINCK_EXAMPLE,
        EXPECTED_SAMPLES_WITH_DESCRIPTIONS.get(KITCHENSINCK_EXAMPLE),
        EXPECTED_KITCHENSINC_REPOSITORY_URL);

    // remove added sample by "Remove" button
    projectOptions.clickOnRemoveButton();
    addOrImportForm.waitProjectTabDisappearance(KITCHENSINCK_EXAMPLE);
    addOrImportForm.waitAddOrImportFormOpened();
    addOrImportForm.waitSamplesButtonSelected();
    addOrImportForm.waitSamplesWithDescriptions(EXPECTED_SAMPLES_WITH_DESCRIPTIONS);
    waitAllCheckboxesDisabled();
    addOrImportForm.waitCancelButtonDisabled();
    addOrImportForm.waitAddButtonDisabled();

    clickOnEachCheckbox();
    waitAllCheckboxesEnabled();
    addOrImportForm.waitCancelButtonEnabled();
    addOrImportForm.waitAddButtonEnabled();

    addOrImportForm.clickOnAddButton();
    addOrImportForm.waitProjectTabAppearance(KITCHENSINCK_EXAMPLE);

    // check name field of the project tab
    addOrImportForm.clickOnProjectTab(KITCHENSINCK_EXAMPLE);
    projectOptions.waitProjectOptionsForm();

    projectOptions.setValueOfNameField("");
    projectOptions.waitProjectNameErrorMessage("A name is required.");
    projectOptions.waitSaveButtonDisabling();
    projectOptions.waitCancelButtonEnabling();

    projectOptions.setValueOfNameField(RENAMED_KITCHENSINK_SAMPLE_NAME);
    projectOptions.waitProjectNameErrorDisappearance();
    projectOptions.waitSaveButtonEnabling();
    projectOptions.waitCancelButtonEnabling();

    projectOptions.setValueOfNameField("");
    projectOptions.waitProjectNameErrorMessage("A name is required.");
    projectOptions.waitSaveButtonDisabling();
    projectOptions.waitCancelButtonEnabling();

    projectOptions.setValueOfNameField(NAME_WITH_MAX_AVAILABLE_LENGTH);
    projectOptions.waitProjectNameErrorDisappearance();
    projectOptions.waitSaveButtonEnabling();
    projectOptions.waitCancelButtonEnabling();

    projectOptions.setValueOfNameField(NAME_WITH_MAX_AVAILABLE_LENGTH + "p");
    projectOptions.waitProjectNameErrorMessage("The name has to be less than 128 characters long.");
    projectOptions.waitSaveButtonDisabling();
    projectOptions.waitCancelButtonEnabling();

    projectOptions.setValueOfNameField(NAME_WITH_SPECIAL_CHARACTERS);
    projectOptions.waitProjectNameErrorMessage(
        "The name should not contain special characters like space, dollar, etc.");
    projectOptions.waitSaveButtonDisabling();
    projectOptions.waitCancelButtonEnabling();

    // check of restoring the previous values of the tab after click "Cancel" button
    projectOptions.typeTextInDescriptionField("");
    projectOptions.clickOnCancelButton();
    checkProjectTabAppearanceAndFields(
        KITCHENSINCK_EXAMPLE,
        EXPECTED_SAMPLES_WITH_DESCRIPTIONS.get(KITCHENSINCK_EXAMPLE),
        EXPECTED_CONSOLE_REPOSITORY_URL);

    // Check "Url" field
    projectOptions.typeTextInRepositoryUrlField("");
    projectOptions.waitRepositoryUrlErrorMessage("Invalid Git URL");
    projectOptions.waitSaveButtonDisabling();
    projectOptions.waitCancelButtonEnabling();

    // check of restoring the previous values of the tab after click "Cancel" button
    projectOptions.clickOnCancelButton();
    checkProjectTabAppearanceAndFields(
        KITCHENSINCK_EXAMPLE,
        EXPECTED_SAMPLES_WITH_DESCRIPTIONS.get(KITCHENSINCK_EXAMPLE),
        EXPECTED_CONSOLE_REPOSITORY_URL);

    // check of restoring the previous values of the tab after click on the another project tab
    // without saving
    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.waitAddOrImportFormOpened();
    addOrImportForm.clickOnSampleCheckbox(KITCHENSINCK_EXAMPLE);
    addOrImportForm.waitSampleCheckboxEnabled(KITCHENSINCK_EXAMPLE);
    addOrImportForm.clickOnAddButton();
    addOrImportForm.waitProjectTabAppearance(KITCHENSINCK_EXAMPLE);
    addOrImportForm.clickOnProjectTab(KITCHENSINCK_EXAMPLE);
    projectOptions.waitProjectNameFieldValue(KITCHENSINCK_EXAMPLE);

    projectOptions.setValueOfNameField("");
    projectOptions.typeTextInDescriptionField("");
    projectOptions.typeTextInRepositoryUrlField("");

    addOrImportForm.clickOnProjectTab(KITCHENSINCK_EXAMPLE);
    projectOptions.waitProjectNameFieldValue(KITCHENSINCK_EXAMPLE);

    addOrImportForm.clickOnProjectTab(KITCHENSINCK_EXAMPLE);
    checkProjectTabAppearanceAndFields(
        KITCHENSINCK_EXAMPLE,
        EXPECTED_SAMPLES_WITH_DESCRIPTIONS.get(KITCHENSINCK_EXAMPLE),
        EXPECTED_CONSOLE_REPOSITORY_URL);

    // check ability of creation the sample with specified valid name
    projectOptions.setValueOfNameField(RENAMED_KITCHENSINK_SAMPLE_NAME);
    projectOptions.clickOnSaveButton();
    addOrImportForm.waitProjectTabAppearance(RENAMED_KITCHENSINK_SAMPLE_NAME);
    projectOptions.waitSaveButtonDisabling();
    projectOptions.waitCancelButtonDisabling();
  }

  @Test(priority = 2)
  public void checkProjectsBlank() {
    // preparing
    newWorkspace.waitPageLoad();
    newWorkspace.selectStack(Stack.JAVA);
    newWorkspace.waitStackSelected(Stack.JAVA);
    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.waitAddOrImportFormOpened();
    addOrImportForm.clickOnBlankButton();

    // check name field
    addOrImportForm.typeToBlankNameField(NAME_WITH_MAX_AVAILABLE_LENGTH);
    addOrImportForm.waitErrorMessageDissappearanceInBlankNameField();
    addOrImportForm.waitAddButtonEnabled();
    addOrImportForm.waitCancelButtonEnabled();

    addOrImportForm.typeToBlankNameField("");
    addOrImportForm.waitAddButtonDisabled();
    addOrImportForm.waitCancelButtonDisabled();

    addOrImportForm.typeToBlankNameField(NAME_WITH_MAX_AVAILABLE_LENGTH + "p");
    addOrImportForm.waitNameFieldErrorMessageInBlankForm(
        "The name has to be less than 128 characters long.");
    addOrImportForm.waitAddButtonDisabled();
    addOrImportForm.waitCancelButtonEnabled();

    addOrImportForm.typeToBlankNameField(NAME_WITH_SPECIAL_CHARACTERS);
    addOrImportForm.waitNameFieldErrorMessageInBlankForm(
        "The name should not contain special characters like space, dollar, etc.");
    addOrImportForm.waitAddButtonDisabled();
    addOrImportForm.waitCancelButtonEnabled();

    // check description field
    addOrImportForm.typeToBlankDescriptionField(BLANK_FORM_DESCRIPTION);
    addOrImportForm.waitTextInBlankDescriptionField(BLANK_FORM_DESCRIPTION);

    addOrImportForm.clickOnCancelButton();
    addOrImportForm.waitTextInBlankNameField("");
    addOrImportForm.waitTextInBlankDescriptionField("");

    // add sample with specified valid name and description
    addOrImportForm.typeToBlankNameField(CUSTOM_BLANK_PROJECT_NAME);
    addOrImportForm.typeToBlankDescriptionField(BLANK_FORM_DESCRIPTION);
    addOrImportForm.clickOnAddButton();

    addOrImportForm.waitProjectTabAppearance(CUSTOM_BLANK_PROJECT_NAME);
    checkProjectTabAppearanceAndFields(
        CUSTOM_BLANK_PROJECT_NAME, BLANK_FORM_DESCRIPTION, BLANK_DEFAULT_URL);

    // check that added by "Git" button project has an expected name and description
    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.waitAddOrImportFormOpened();

    addOrImportForm.clickOnGitButton();
    addOrImportForm.waitGitTabOpened();

    addOrImportForm.typeToGitUrlField(BLANK_DEFAULT_URL);
    addOrImportForm.clickOnAddButton();
    checkProjectTabAppearanceAndFields(BLANK_PROJECT_NAME, "", BLANK_DEFAULT_URL);
  }

  @Test(priority = 3)
  public void checkCreatingProject() throws Exception {
    // check that name field saves it state after choosing another stack
    newWorkspace.waitPageLoad();
    newWorkspace.typeWorkspaceName(WORKSPACE_NAME);
    newWorkspace.selectStack(Stack.DOT_NET);
    newWorkspace.waitStackSelected(Stack.DOT_NET);
    assertEquals(newWorkspace.getWorkspaceNameValue(), WORKSPACE_NAME);

    newWorkspace.selectStack(Stack.JAVA);
    newWorkspace.waitStackSelected(Stack.JAVA);
    assertEquals(newWorkspace.getWorkspaceNameValue(), WORKSPACE_NAME);

    // add workspace with specified "RAM" value
    newWorkspace.setMachineRAM("dev-machine", 2.0);
    newWorkspace.waitRamValue("dev-machine", 2.0);

    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.waitAddOrImportFormOpened();

    addOrImportForm.clickOnSampleCheckbox(KITCHENSINCK_EXAMPLE);
    addOrImportForm.waitSampleCheckboxEnabled(KITCHENSINCK_EXAMPLE);

    addOrImportForm.clickOnAddButton();
    addOrImportForm.waitProjectTabAppearance(KITCHENSINCK_EXAMPLE);

    // check closing of "Workspace Is Created" dialog window
    newWorkspace.clickOnBottomCreateButton();
    newWorkspace.waitWorkspaceCreatedDialogIsVisible();

    newWorkspace.closeWorkspaceCreatedDialog();
    newWorkspace.waitWorkspaceCreatedDialogDisappearance();
    workspaceOverview.checkNameWorkspace(WORKSPACE_NAME);

    seleniumWebDriver.navigate().back();

    prepareJavaWorkspaceAndOpenCreateDialog(TEST_JAVA_WORKSPACE_NAME);
    newWorkspace.clickOnEditWorkspaceButton();
    workspaceOverview.checkNameWorkspace(TEST_JAVA_WORKSPACE_NAME);

    seleniumWebDriver.navigate().back();

    prepareJavaWorkspaceAndOpenCreateDialog(TEST_JAVA_WORKSPACE_NAME_EDIT);
    newWorkspace.waitWorkspaceCreatedDialogIsVisible();
    newWorkspace.clickOnOpenInIDEButton();

    // store info about created workspace to make SeleniumTestHandler.captureTestWorkspaceLogs()
    // possible to read logs in case of test failure
    testWorkspace =
        testWorkspaceProvider.getWorkspace(TEST_JAVA_WORKSPACE_NAME_EDIT, defaultTestUser);

    testWorkspaceServiceClient.waitStatus(
        TEST_JAVA_WORKSPACE_NAME_EDIT, defaultTestUser.getName(), RUNNING);
    seleniumWebDriverHelper.switchToIdeFrameAndWaitAvailability();

    projectExplorer.waitProjectExplorer();
    projectExplorer.waitItem(KITCHENSINCK_EXAMPLE);
  }

  private void waitAllCheckboxesDisabled() {
    addOrImportForm
        .getSamplesNames()
        .forEach(sampleName -> addOrImportForm.waitSampleCheckboxDisabled(sampleName));
  }

  private void waitAllCheckboxesEnabled() {
    addOrImportForm
        .getSamplesNames()
        .forEach(sampleName -> addOrImportForm.waitSampleCheckboxEnabled(sampleName));
  }

  private void clickOnEachCheckbox() {
    addOrImportForm
        .getSamplesNames()
        .forEach(sampleName -> addOrImportForm.clickOnSampleCheckbox(sampleName));
  }

  private void checkProjectTabAppearanceAndFields(
      String tabName, String expectedDescription, String expectedUrl) {
    projectOptions.waitProjectOptionsForm();
    projectOptions.waitProjectNameFieldValue(tabName);
    projectOptions.waitDescriptionFieldValue(expectedDescription);
    projectOptions.waitRepositoryUrlFieldValue(expectedUrl);
    projectOptions.waitRemoveButton();
    projectOptions.waitCancelButtonDisabling();
    projectOptions.waitSaveButtonDisabling();
  }

  private void prepareJavaWorkspaceAndOpenCreateDialog(String workspaceName) {
    // prepare workspace
    newWorkspace.waitPageLoad();
    newWorkspace.typeWorkspaceName(workspaceName);

    newWorkspace.selectStack(Stack.JAVA);
    newWorkspace.waitStackSelected(Stack.JAVA);

    addOrImportForm.clickOnAddOrImportProjectButton();
    addOrImportForm.waitAddOrImportFormOpened();

    addOrImportForm.clickOnSampleCheckbox(KITCHENSINCK_EXAMPLE);
    addOrImportForm.waitSampleCheckboxEnabled(KITCHENSINCK_EXAMPLE);

    addOrImportForm.clickOnAddButton();
    checkProjectTabAppearanceAndFields(
        KITCHENSINCK_EXAMPLE,
        EXPECTED_SAMPLES_WITH_DESCRIPTIONS.get(KITCHENSINCK_EXAMPLE),
        EXPECTED_KITCHENSINC_REPOSITORY_URL);

    // open create dialog
    newWorkspace.clickOnBottomCreateButton();
    newWorkspace.waitWorkspaceCreatedDialogIsVisible();
  }
}
