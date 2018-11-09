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
package com.redhat.codeready.selenium.miscellaneous;

import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.eclipse.che.selenium.core.TestGroup.UNDER_REPAIR;
import static org.eclipse.che.selenium.pageobject.PanelSelector.PanelTypes.LEFT_BOTTOM_ID;
import static org.testng.Assert.fail;

import com.google.inject.Inject;
import java.net.URL;
import java.nio.file.Paths;
import org.eclipse.che.selenium.core.client.TestProjectServiceClient;
import org.eclipse.che.selenium.core.constant.TestBuildConstants;
import org.eclipse.che.selenium.core.constant.TestTimeoutsConstants;
import org.eclipse.che.selenium.core.project.ProjectTemplates;
import org.eclipse.che.selenium.core.utils.WaitUtils;
import org.eclipse.che.selenium.core.workspace.TestWorkspace;
import org.eclipse.che.selenium.pageobject.CheTerminal;
import org.eclipse.che.selenium.pageobject.Consoles;
import org.eclipse.che.selenium.pageobject.Ide;
import org.eclipse.che.selenium.pageobject.Loader;
import org.eclipse.che.selenium.pageobject.PanelSelector;
import org.eclipse.che.selenium.pageobject.ProjectExplorer;
import org.openqa.selenium.Keys;
import org.openqa.selenium.TimeoutException;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.BeforeMethod;
import org.testng.annotations.Test;

/**
 * @author Aleksandr Shmaraev
 * @author Alexander Andrienko
 */
public class WorkingWithTerminalTest {

  private static final String PROJECT_NAME = generate("project", 4);
  private static final String MESS_IN_CONSOLE =
      "Installing /projects/" + PROJECT_NAME + "/target/qa-spring-sample-1.0-SNAPSHOT.war";
  private static final String WAR_NAME = "qa-spring-sample-1.0-SNAPSHOT.war";
  private static final String BASH_SCRIPT =
      "for i in `seq 1 10`; do sleep 1; echo \"test=$i\"; done";

  @Inject private Ide ide;
  @Inject private Loader loader;
  @Inject private Consoles consoles;
  @Inject private CheTerminal terminal;
  @Inject private TestWorkspace workspace;
  @Inject private PanelSelector panelSelector;
  @Inject private ProjectExplorer projectExplorer;
  @Inject private TestProjectServiceClient testProjectServiceClient;

  @BeforeClass
  public void setUp() throws Exception {
    URL resource = getClass().getResource("/projects/guess-project");
    testProjectServiceClient.importProject(
        workspace.getId(),
        Paths.get(resource.toURI()),
        PROJECT_NAME,
        ProjectTemplates.MAVEN_SPRING);
    ide.open(workspace);
    ide.waitOpenedWorkspaceIsReadyToUse();
  }

  @BeforeMethod
  private void prepareNewTerminal() {
    panelSelector.selectPanelTypeFromPanelSelector(LEFT_BOTTOM_ID);

    projectExplorer.waitItem(PROJECT_NAME);

    if (terminal.terminalIsPresent()) {
      consoles.closeTerminalIntoConsoles();
      terminal.waitTerminalIsNotPresent(1);
    }

    consoles.clickOnPlusMenuButton();
    consoles.clickOnTerminalItemInContextMenu();

    terminal.selectFirstTerminalTab();
    terminal.waitTerminalConsole();
    terminal.waitFirstTerminalIsNotEmpty();
  }

  @Test
  public void shouldLaunchCommandWithBigOutput() {
    // build the web java application
    projectExplorer.waitProjectExplorer();
    loader.waitOnClosed();
    projectExplorer.waitItem(PROJECT_NAME);
    terminal.waitTerminalConsole(1);
    terminal.typeIntoActiveTerminal("cd /projects/" + PROJECT_NAME + Keys.ENTER);
    terminal.waitTextInFirstTerminal("/projects/" + PROJECT_NAME);
    terminal.typeIntoActiveTerminal("mvn clean install" + Keys.ENTER);
    terminal.waitTextInTerminal(
        TestBuildConstants.BUILD_SUCCESS, TestTimeoutsConstants.EXPECTED_MESS_IN_CONSOLE_SEC);
    terminal.waitTextInFirstTerminal(MESS_IN_CONSOLE);

    // check the target folder
    projectExplorer.openItemByPath(PROJECT_NAME);
    projectExplorer.openItemByPath(PROJECT_NAME + "/target");
    projectExplorer.waitItem(PROJECT_NAME + "/target/" + WAR_NAME);
  }

  @Test
  public void shouldCreateFileTest() {
    terminal.typeIntoActiveTerminal("cd ~" + Keys.ENTER);
    terminal.typeIntoActiveTerminal("ls" + Keys.ENTER);
    terminal.waitTextInFirstTerminal("che");
    terminal.typeIntoActiveTerminal("touch a.txt" + Keys.ENTER);

    terminal.typeIntoActiveTerminal("ls" + Keys.ENTER);
    terminal.waitTextInFirstTerminal("che");
    terminal.waitTextInFirstTerminal("a.txt");
  }

  @Test(groups = UNDER_REPAIR)
  public void shouldCancelProcessByCtrlC() {
    terminal.typeIntoActiveTerminal("cd /" + Keys.ENTER);

    // launch bash script
    terminal.typeIntoActiveTerminal(BASH_SCRIPT + Keys.ENTER);
    terminal.waitTextInFirstTerminal("test=1");

    // cancel script
    terminal.typeIntoActiveTerminal(Keys.CONTROL + "c");

    // wait 1 sec. If process was really stopped we should not get text "test=2"
    WaitUtils.sleepQuietly(1);

    try {
      terminal.waitNoTextInFirstTerminal("test=2");
    } catch (TimeoutException ex) {
      // remove try-catch block after issue has been resolved
      fail("Known permanent failure https://github.com/eclipse/che/issues/8390");
    }
  }

  @Test
  public void shouldBeClear() {
    terminal.typeIntoActiveTerminal("cd / && ls -l" + Keys.ENTER);

    // clear terminal
    terminal.typeIntoActiveTerminal("clear" + Keys.ENTER);
    terminal.waitNoTextInFirstTerminal("clear");
    terminal.waitTextInFirstTerminal("@");
  }

  @Test
  public void shouldBeReset() {
    terminal.typeIntoActiveTerminal("cd / && ls -l" + Keys.ENTER);

    // clear terminal
    terminal.typeIntoActiveTerminal("reset" + Keys.ENTER.toString());
    terminal.waitNoTextInFirstTerminal("reset");
    terminal.waitTextInFirstTerminal("@");
  }

  @Test
  public void closeTerminalByExitCommand() {
    terminal.waitTerminalConsole();
    terminal.typeIntoActiveTerminal("exit" + Keys.ENTER);
    terminal.waitTerminalIsNotPresent(1);
  }

  @Test
  public void checkDeleteAction() {
    // if the bug exists -> the dialog appears and the terminal lose focus
    terminal.typeIntoActiveTerminal(Keys.DELETE.toString());
    terminal.typeIntoActiveTerminal("pwd");
  }
}
