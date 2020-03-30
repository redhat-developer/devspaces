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
import java.util.Collections;
import org.eclipse.che.selenium.core.SeleniumWebDriver;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.pageobject.dashboard.CreateWorkspaceHelper;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Devfile;
import org.eclipse.che.selenium.pageobject.theia.TheiaEditor;
import org.eclipse.che.selenium.pageobject.theia.TheiaIde;
import org.eclipse.che.selenium.pageobject.theia.TheiaProjectTree;
import org.testng.annotations.AfterClass;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

/** @author Andrey chizhikov */
@Test
public class ProjectStateAfterRefreshTest {
  private static final String WORKSPACE_NAME =
      generate(ProjectStateAfterRefreshTest.class.getSimpleName(), 5);
  private static final String PROJECT_NAME = "vertx-health-checks-example-redhat";
  private static final String PATH_TO_POM_FILE = PROJECT_NAME + "/" + "pom.xml";
  private static final String PATH_TO_README_FILE = PROJECT_NAME + "/" + "README.md";

  @Inject private Dashboard dashboard;
  @Inject private TestWorkspaceServiceClient workspaceServiceClient;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private CreateWorkspaceHelper createWorkspaceHelper;
  @Inject private TheiaIde theiaIde;
  @Inject private TheiaProjectTree theiaProjectTree;
  @Inject private SeleniumWebDriver seleniumWebDriver;
  @Inject private TheiaEditor theiaEditor;

  @BeforeClass
  public void setUp() throws Exception {
    dashboard.open();
    createWorkspaceHelper.createAndStartWorkspaceFromStack(
        Devfile.JAVA_MAVEN, WORKSPACE_NAME, Collections.emptyList(), null);
  }

  @AfterClass
  public void tearDown() throws Exception {
    workspaceServiceClient.delete(WORKSPACE_NAME, defaultTestUser.getName());
  }

  @Test
  public void checkRestoreStateOfProjectAfterRefreshTest() {
    theiaIde.waitOpenedWorkspaceIsReadyToUse();

    theiaProjectTree.waitFilesTab();
    theiaProjectTree.clickOnFilesTab();
    theiaProjectTree.waitProjectAreaOpened();
    theiaProjectTree.waitItem(PROJECT_NAME);
    theiaIde.waitAllNotificationsClosed();

    openFilesInEditor();
    checkFilesAreOpened();

    seleniumWebDriver.navigate().refresh();
    theiaIde.waitOpenedWorkspaceIsReadyToUse();

    checkFilesAreOpened();
  }

  private void openFilesInEditor() {
    theiaProjectTree.expandItem(PROJECT_NAME);
    theiaProjectTree.waitItem(PATH_TO_POM_FILE);
    theiaProjectTree.waitItem(PATH_TO_README_FILE);

    theiaProjectTree.openItem(PATH_TO_POM_FILE);
    theiaProjectTree.openItem(PATH_TO_README_FILE);
  }

  private void checkFilesAreOpened() {
    theiaEditor.waitEditorTab("pom.xml");
    theiaEditor.waitEditorTab("README.md");
  }
}
