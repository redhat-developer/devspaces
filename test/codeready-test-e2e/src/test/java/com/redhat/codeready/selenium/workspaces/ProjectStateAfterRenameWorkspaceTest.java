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

import static org.eclipse.che.commons.lang.NameGenerator.generate;

import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyCreateWorkspaceHelper;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Devfile;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceDetails;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.WorkspaceOverview;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.eclipse.che.selenium.pageobject.theia.TheiaEditor;
import org.eclipse.che.selenium.pageobject.theia.TheiaIde;
import org.eclipse.che.selenium.pageobject.theia.TheiaProjectTree;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/** @author Aleksandr Shmaraev */
@Test
public class ProjectStateAfterRenameWorkspaceTest {
  private static final String PROJECT_NAME = "vertx-health-checks-example-redhat";
  private static final String WORKSPACE_NEW_NAME = generate("rename_ws", 4);
  private static final String PATH_TO_POM_FILE = PROJECT_NAME + "/" + "pom.xml";
  private static final String PATH_TO_README_FILE = PROJECT_NAME + "/" + "README.md";

  @Inject private Dashboard dashboard;
  @Inject private TestWorkspaceServiceClient workspaceServiceClient;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private CodereadyCreateWorkspaceHelper codereadyCreateWorkspaceHelper;
  @Inject private TheiaIde theiaIde;
  @Inject private TheiaProjectTree theiaProjectTree;
  @Inject private TheiaEditor theiaEditor;
  @Inject private WorkspaceDetails workspaceDetails;
  @Inject private Workspaces workspaces;
  @Inject private WorkspaceOverview workspaceOverview;

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
    workspaceServiceClient.delete(WORKSPACE_NEW_NAME, defaultTestUser.getName());
  }

  @Test
  public void checkProjectAfterRenameWs() {
    theiaProjectTree.waitFilesTab();
    theiaProjectTree.clickOnFilesTab();
    theiaProjectTree.waitProjectAreaOpened();
    theiaProjectTree.waitItem(PROJECT_NAME);
    theiaIde.waitAllNotificationsClosed();

    openFilesInEditor();
    checkFilesAreOpened();

    // go to dashboard and rename ws
    dashboard.open();
    dashboard.waitDashboardToolbarTitle();
    dashboard.selectWorkspacesItemOnDashboard();
    dashboard.waitToolbarTitleName("Workspaces");
    workspaces.selectWorkspaceItemName(workspaceName);
    workspaceOverview.enterNameWorkspace(WORKSPACE_NEW_NAME);
    workspaceDetails.clickOnSaveChangesBtn();
    dashboard.waitNotificationMessage("Workspace updated");
    dashboard.waitNotificationIsClosed();
    workspaceOverview.checkNameWorkspace(WORKSPACE_NEW_NAME);
    workspaceDetails.clickOpenInIdeWsBtn();

    theiaIde.waitOpenedWorkspaceIsReadyToUse();

    checkFilesAreOpened();
  }

  private void openFilesInEditor() {
    theiaProjectTree.expandItem(PROJECT_NAME);
    theiaProjectTree.waitItem(PATH_TO_POM_FILE);
    theiaProjectTree.waitItem(PATH_TO_README_FILE);

    theiaProjectTree.openItem(PATH_TO_POM_FILE);
    theiaProjectTree.openItem(PATH_TO_README_FILE);
    theiaEditor.waitEditorTab("pom.xml");
    theiaEditor.waitEditorTab("README.md");
  }

  private void checkFilesAreOpened() {
    theiaEditor.waitEditorTab("pom.xml");
    theiaEditor.waitEditorTab("README.md");
  }
}
