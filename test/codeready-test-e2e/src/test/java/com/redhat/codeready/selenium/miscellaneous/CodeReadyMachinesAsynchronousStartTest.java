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

import static java.lang.String.format;

import org.eclipse.che.selenium.miscellaneous.MachinesAsynchronousStartTest;

/** @author Aleksandr Shmaraev */
public class CodeReadyMachinesAsynchronousStartTest extends MachinesAsynchronousStartTest {

  @Override
  protected String getImageName() {
    return "registry.access.redhat.com/codeready-workspaces/stacks-java";
  }

  @Override
  protected String getExpectedErrorNotificationText() {
    return format(
        "Unrecoverable event occurred: 'Failed', 'Failed to pull image \"%s\": rpc error: code = Unknown desc",
        NOT_EXISTED_IMAGE_NAME);
  }
}
