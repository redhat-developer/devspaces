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
package com.redhat.codeready.selenium.dashboard;

import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Stack.DOT_NET;
import static org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Stack.JAVA;
import static org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Stack.NODE;
import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertFalse;
import static org.testng.Assert.assertTrue;

import com.google.inject.Inject;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace;
import org.eclipse.che.selenium.pageobject.dashboard.ProjectSourcePage;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.BeforeMethod;
import org.testng.annotations.Test;

/** @author Serhii Skoryk */
public class CreateWorkspaceTest {

  private final String WORKSPACE_NAME = generate("workspace", 4);
  private static final String MIN_VALID_WORKSPACE_NAME = generate("", 3);
  private static final String TOO_SHORT_WORKSPACE_NAME = generate("", 2);
  private static final String MAX_VALID_WORKSPACE_NAME = generate("", 100);
  private static final String TOO_LONG_WORKSPACE_NAME = generate("", 101);
  private static final String WS_NAME_TOO_SHORT =
      ("The name has to be more than 3 characters long.");
  private static final String WS_NAME_TOO_LONG =
      ("The name has to be less than 100 characters long.");

  private String projectName = "kitchensink-example";
  private String newProjectName = projectName + "-1";
  private String projectDescription = "This is the kitchensink JBoss quickstart app";
  private String newProjectDescription = "This is " + projectDescription;

  @Inject private Dashboard dashboard;
  @Inject private NewWorkspace newWorkspace;
  @Inject private ProjectSourcePage projectSourcePage;
  @Inject private Workspaces workspaces;

  @BeforeClass
  public void setUp() {
    dashboard.open();
  }

  @BeforeMethod
  private void openNewWorkspacePage() {
    dashboard.selectWorkspacesItemOnDashboard();
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.waitToolbar();
  }

  @Test
  public void checkWorkspaceName() {
    newWorkspace.typeWorkspaceName(TOO_SHORT_WORKSPACE_NAME);
    newWorkspace.waitErrorMessage(WS_NAME_TOO_SHORT);

    newWorkspace.waitBottomCreateWorkspaceButtonDisabled();

    newWorkspace.typeWorkspaceName(TOO_LONG_WORKSPACE_NAME);
    newWorkspace.waitErrorMessage(WS_NAME_TOO_LONG);
    newWorkspace.waitBottomCreateWorkspaceButtonDisabled();

    // type valid names and check that the Create button is enabled
    newWorkspace.typeWorkspaceName(MIN_VALID_WORKSPACE_NAME);
    newWorkspace.waitBottomCreateWorkspaceButtonEnabled();

    newWorkspace.typeWorkspaceName(WORKSPACE_NAME);
    newWorkspace.waitBottomCreateWorkspaceButtonEnabled();

    newWorkspace.typeWorkspaceName(MAX_VALID_WORKSPACE_NAME);
    newWorkspace.waitBottomCreateWorkspaceButtonEnabled();
  }

  @Test
  public void checkMachines() {
    String machineName = "dev-machine";

    // change the RAM number by the increment and decrement buttons
    newWorkspace.clickOnAllStacksTab();
    newWorkspace.selectStack(JAVA);
    assertTrue(newWorkspace.isMachineExists(machineName));
    assertEquals(newWorkspace.getRAM(machineName), 2.0);
    newWorkspace.clickOnIncrementMemoryButton(machineName);
    assertEquals(newWorkspace.getRAM(machineName), 2.5);
    newWorkspace.clickOnDecrementMemoryButton(machineName);
    newWorkspace.clickOnDecrementMemoryButton(machineName);
    newWorkspace.clickOnDecrementMemoryButton(machineName);
    assertEquals(newWorkspace.getRAM(machineName), 1.0);

    // type number of memory in the RAM field
    newWorkspace.setMachineRAM(machineName, 5.0);
    assertEquals(newWorkspace.getRAM(machineName), 5.0);
  }

  @Test
  public void checkFiltersStacksFeature() {

    // filter stacks by 'java' value and check filtered stacks list
    newWorkspace.clickOnAllStacksTab();
    newWorkspace.clickOnFiltersButton();
    newWorkspace.typeToFiltersInput("java");
    newWorkspace.chooseFilterSuggestionByPlusButton("JAVA");
    assertTrue(newWorkspace.isStackVisible(JAVA));

    newWorkspace.clickOnMultiMachineTab();
    assertFalse(newWorkspace.isStackVisible(JAVA));

    newWorkspace.clickOnFiltersButton();
    newWorkspace.clearSuggestions();
  }

  @Test
  public void checkSearchStackFeature() {
    newWorkspace.clickOnAllStacksTab();

    // search stacks with 'java' value
    newWorkspace.typeToSearchInput("java");

    assertTrue(newWorkspace.isStackVisible(JAVA));
    assertFalse(newWorkspace.isStackVisible(NODE));
    newWorkspace.clearTextInSearchInput();

    // search stacks with 'node' value
    newWorkspace.typeToSearchInput("node");
    assertTrue(newWorkspace.isStackVisible(NODE));
    assertFalse(newWorkspace.isStackVisible(JAVA));

    // search stacks with '.net' value
    newWorkspace.typeToSearchInput(".net");
    assertTrue(newWorkspace.isStackVisible(DOT_NET));
    assertFalse(newWorkspace.isStackVisible(JAVA));

    newWorkspace.clearTextInSearchInput();
  }

  @Test
  public void checkProjectSourcePage() {
    newWorkspace.clickOnAllStacksTab();

    // add a project from the 'kitchensink-example' sample
    newWorkspace.selectStack(JAVA);
    projectSourcePage.clickOnAddOrImportProjectButton();
    projectSourcePage.selectSample(projectName);
    projectSourcePage.clickOnAddProjectButton();
    projectSourcePage.waitCreatedProjectButton(projectName);
    projectSourcePage.clickOnCreateProjectButton(projectName);

    // change the added project's name and cancel changes
    assertEquals(projectSourcePage.getProjectName(), projectName);
    assertEquals(projectSourcePage.getProjectDescription(), projectDescription);
    projectSourcePage.changeProjectName(newProjectName);
    projectSourcePage.changeProjectDescription(newProjectDescription);
    assertEquals(projectSourcePage.getProjectDescription(), newProjectDescription);
    assertEquals(projectSourcePage.getProjectName(), newProjectName);
    projectSourcePage.clickOnCancelChangesButton();
    assertEquals(projectSourcePage.getProjectName(), projectName);
    assertEquals(projectSourcePage.getProjectDescription(), projectDescription);
    projectSourcePage.waitCreatedProjectButton(projectName);

    // change the added project's name and description
    projectSourcePage.changeProjectName(newProjectName);
    projectSourcePage.changeProjectDescription(newProjectDescription);
    assertEquals(projectSourcePage.getProjectDescription(), newProjectDescription);
    assertEquals(projectSourcePage.getProjectName(), newProjectName);
    projectSourcePage.clickOnSaveChangesButton();
    assertEquals(projectSourcePage.getProjectDescription(), newProjectDescription);
    assertEquals(projectSourcePage.getProjectName(), newProjectName);
    projectSourcePage.waitCreatedProjectButton(newProjectName);

    // remove the added project
    projectSourcePage.clickOnRemoveProjectButton();
    assertTrue(projectSourcePage.isProjectNotExists(newProjectName));
  }
}
