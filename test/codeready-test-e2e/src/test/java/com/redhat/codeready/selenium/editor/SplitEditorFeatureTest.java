/*
 * Copyright (c) 2012-2018 Red Hat, Inc.
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Contributors:
 *   Red Hat, Inc. - initial API and implementation
 */
package com.redhat.codeready.selenium.editor;

import static org.eclipse.che.selenium.core.constant.TestTimeoutsConstants.LOAD_PAGE_TIMEOUT_SEC;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.TabActionLocator;
import static org.eclipse.che.selenium.pageobject.CodenvyEditor.TabActionLocator.SPIT_HORISONTALLY;
import static org.testng.Assert.assertTrue;

import com.google.inject.Inject;
import org.eclipse.che.commons.lang.NameGenerator;
import org.eclipse.che.selenium.core.constant.TestMenuCommandsConstants;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.pageobject.AskForValueDialog;
import org.eclipse.che.selenium.pageobject.CodenvyEditor;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.Loader;
import org.eclipse.che.selenium.pageobject.Menu;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.eclipse.che.selenium.pageobject.Refactor;
import org.eclipse.che.selenium.pageobject.Wizard;
import org.openqa.selenium.Keys;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.Test;

public class SplitEditorFeatureTest {

  private static final String PROJECT_NAME =
      NameGenerator.generate(SplitEditorFeatureTest.class.getSimpleName(), 4);
  private static final String SAMPLE_NAME = "kitchensink-example";
  private static final String TEXT_FILE = "README.md";
  private static final String PATH_TEXT_FILE = PROJECT_NAME + "/" + TEXT_FILE;
  private static final String NAME_JAVA_CLASS = "MemberRegistration";
  private static final String PATH_TO_PACKAGE =
      PROJECT_NAME + "/src/main/java/org.jboss.as.quickstarts.kitchensink/controller";
  private static final String PATH_JAVA_FILE =
      PROJECT_NAME
          + "/src/main/java/org/jboss/as/quickstarts/kitchensink/controller/"
          + NAME_JAVA_CLASS
          + ".java";
  private static final String NEW_NAME = "NewName";
  private static final String NEW_NAME_JAVA = "NewName.java";
  private static final String NEW_NAME_TXT_FILE = "NewREADME";

  private static final String TEXT = "some text";

  @Inject private TestWorkspace workspace;
  @Inject private DefaultTestUser defaultTestUser;
  @Inject private Ide ide;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private Loader loader;
  @Inject private CodenvyEditor editor;
  @Inject private AskForValueDialog askForValueDialog;
  @Inject private Menu menu;
  @Inject private Refactor refactor;
  @Inject private Wizard wizard;
  @Inject private Consoles consoles;

  @BeforeClass
  public void setUp() throws Exception {
    String javaFileName = "MemberRegistration.java";
    ide.open(workspace);
    createProject(PROJECT_NAME);
    // consoles.waitJDTLSProjectResolveFinishedMessage(PROJECT_NAME);
    projectExplorer.waitAndSelectItem(PROJECT_NAME);
    projectExplorer.expandPathInProjectExplorerAndOpenFile(PATH_TO_PACKAGE, javaFileName);
    editor.waitTabIsPresent(NAME_JAVA_CLASS);
    editor.waitTabSelection(0, NAME_JAVA_CLASS);
    editor.waitActive();
  }

  @Test
  public void checkSplitEditorWindow() {
    editor.openAndWaitContextMenuForTabByName(NAME_JAVA_CLASS);
    editor.runActionForTabFromContextMenu(SPIT_HORISONTALLY);

    editor.waitCountTabsWithProvidedName(2, NAME_JAVA_CLASS);

    editor.selectTabByIndexEditorWindowAndOpenMenu(0, NAME_JAVA_CLASS);
    editor.runActionForTabFromContextMenu(TabActionLocator.SPLIT_VERTICALLY);
    editor.waitCountTabsWithProvidedName(3, NAME_JAVA_CLASS);

    editor.selectTabByIndexEditorWindow(1, NAME_JAVA_CLASS);
    editor.waitTabSelection(1, NAME_JAVA_CLASS);
    editor.waitActive();
    editor.typeTextIntoEditor(Keys.ENTER.toString());
    editor.typeTextIntoEditor(Keys.UP.toString());
    editor.typeTextIntoEditor(TEXT);

    selectSplittedTabAndWaitExpectedText(0, NAME_JAVA_CLASS, TEXT);

    selectSplittedTabAndWaitExpectedText(1, NAME_JAVA_CLASS, TEXT);

    selectSplittedTabAndWaitExpectedText(2, NAME_JAVA_CLASS, TEXT);
  }

  @Test(priority = 1)
  public void checkFocusInCurrentWindow() {
    editor.selectTabByIndexEditorWindow(1, NAME_JAVA_CLASS);
    editor.waitTabSelection(1, NAME_JAVA_CLASS);
    editor.waitActive();
    projectExplorer.openItemByPath(PATH_TEXT_FILE);
    editor.waitTabIsPresent(TEXT_FILE);
    editor.waitTabFocusing(0, TEXT_FILE);
    editor.waitActive();
    assertTrue(editor.tabIsPresentOnce(TEXT_FILE));
  }

  @Test(priority = 2)
  public void checkRefactoring() {
    editor.selectTabByIndexEditorWindow(2, NAME_JAVA_CLASS);
    editor.waitActive();
    projectExplorer.waitAndSelectItem(PATH_JAVA_FILE);

    projectExplorer.launchRefactorByKeyboard();
    refactor.typeAndWaitNewName(NEW_NAME_JAVA);
    refactor.clickOkButtonRefactorForm();
    editor.waitActive();

    editor.selectTabByIndexEditorWindow(1, NEW_NAME);
    editor.waitActive();

    editor.selectTabByIndexEditorWindow(0, NEW_NAME);
    editor.waitActive();
    editor.setCursorToLine(2);
    editor.typeTextIntoEditor("//" + TEXT);
    editor.waitTextIntoEditor("//" + TEXT);

    selectSplittedTabAndWaitExpectedText(1, NEW_NAME, "//" + TEXT);

    selectSplittedTabAndWaitExpectedText(2, NEW_NAME, "//" + TEXT);
  }

  @Test(priority = 3)
  public void checkContentAfterRenameFile() {
    editor.selectTabByIndexEditorWindow(0, NEW_NAME);
    projectExplorer.openItemByPath(PATH_TEXT_FILE);
    editor.waitActive();
    editor.selectTabByIndexEditorWindow(2, NEW_NAME);
    projectExplorer.openItemByPath(PATH_TEXT_FILE);
    editor.waitActive();
    renameFile(PATH_TEXT_FILE);
    editor.selectTabByIndexEditorWindow(0, NEW_NAME_TXT_FILE);
    editor.waitActive();
    editor.setCursorToLine(3);
    editor.typeTextIntoEditor("***" + TEXT);
    editor.waitTextIntoEditor("***" + TEXT);

    selectSplittedTabAndWaitExpectedText(1, NEW_NAME_TXT_FILE, "***" + TEXT);

    selectSplittedTabAndWaitExpectedText(2, NEW_NAME_TXT_FILE, "***" + TEXT);
  }

  private void createProject(String projectName) {
    projectExplorer.waitProjectExplorer();
    loader.waitOnClosed();
    menu.runCommand(
        TestMenuCommandsConstants.Workspace.WORKSPACE,
        TestMenuCommandsConstants.Workspace.CREATE_PROJECT);
    wizard.waitCreateProjectWizardForm();
    wizard.typeProjectNameOnWizard(projectName);
    wizard.selectSample(SAMPLE_NAME);
    wizard.clickCreateButton();
    loader.waitOnClosed();
    wizard.waitCloseProjectConfigForm();
    loader.waitOnClosed();
    projectExplorer.waitProjectExplorer();
    projectExplorer.waitItem(projectName);
    loader.waitOnClosed();
  }

  private void renameFile(String pathToFile) {
    projectExplorer.waitAndSelectItem(pathToFile);
    menu.runCommand(TestMenuCommandsConstants.Edit.EDIT, TestMenuCommandsConstants.Edit.RENAME);
    askForValueDialog.waitFormToOpen();
    askForValueDialog.clearInput();
    askForValueDialog.typeAndWaitText(NEW_NAME_TXT_FILE);
    askForValueDialog.clickOkBtn();
    askForValueDialog.waitFormToClose();
  }

  private void selectSplittedTabAndWaitExpectedText(
      int tabIndex, String tabName, String expectedText) {
    editor.selectTabByIndexEditorWindow(tabIndex, tabName);
    editor.waitTabSelection(tabIndex, tabName);
    editor.waitActive();
    editor.waitTextInDefinedSplitEditor(tabIndex + 1, LOAD_PAGE_TIMEOUT_SEC, expectedText);
  }

  private void selectSplittedTabAndWaitTextIsNotPresent(int tabIndex, String tabName, String text) {
    editor.selectTabByIndexEditorWindow(tabIndex, tabName);
    editor.waitTabSelection(tabIndex, tabName);
    editor.waitActive();
    editor.waitTextIsNotPresentInDefinedSplitEditor(tabIndex + 1, LOAD_PAGE_TIMEOUT_SEC, text);
  }
}
