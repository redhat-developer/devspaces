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
package com.redhat.codeready.selenium.debugger;

import org.eclipse.che.selenium.core.constant.TestCommandsConstants;
import org.eclipse.che.selenium.debugger.StepIntoStepOverStepReturnWithChangeVariableTest;
import org.testng.annotations.AfterMethod;
import org.testng.annotations.Test;

/**
 * @author Dmytro Nochevnov
 * @author Aleksandr Shmaraiev
 *     <p>Note: test are being overrided in class to support proper sequence of tests (issue
 *     CRW-155).
 */
public class CodeReadyStepIntoStepOverStepReturnWithChangeVariableTest
    extends StepIntoStepOverStepReturnWithChangeVariableTest {

  @Override
  protected void createStartDebugCommmand() throws Exception {
    testCommandServiceClient.createCommand(
        "cp /projects/"
            + PROJECT
            + "/target/qa-spring-sample-1.0-SNAPSHOT.war /opt/eap/standalone/deployments/ROOT.war"
            + " && unset JAVA_OPTS &&"
            + "/opt/eap/bin/standalone.sh -b 0.0.0.0 --debug 8000",
        START_DEBUG,
        TestCommandsConstants.CUSTOM,
        ws.getId());
  }

  @Override
  protected void createBuildCommand() throws Exception {
    testCommandServiceClient.createCommand(
        "mvn clean install -f ${current.project.path}/pom.xml",
        BUILD,
        TestCommandsConstants.CUSTOM,
        ws.getId());
  }

  @Override
  protected void stopDebuggerAndCleanUp() {
    consoles.clickOnProcessesButton();
    consoles.closeProcessTabWithAskDialog(START_DEBUG);
  }

  @Override
  protected void waitExpectedTextIntoConsole() {
    consoles.waitExpectedTextIntoConsole("started in");
  }

  @Override
  protected String getApplicationUrl() throws Exception {
    return workspaceServiceClient
            .getServerFromDevMachineBySymbolicName(ws.getId(), "eap")
            .getUrl()
            .replace("tcp", "http")
        + "/spring/guess";
  }

  @AfterMethod
  @Override
  public void shutDownAndCleanWebApp() {
    super.shutDownAndCleanWebApp();
  }

  @Test
  @Override
  public void changeVariableTest() throws Exception {
    super.changeVariableTest();
  }

  @Test(priority = 1)
  @Override
  public void shouldOpenDebuggingFile() {
    super.shouldOpenDebuggingFile();
  }
}
