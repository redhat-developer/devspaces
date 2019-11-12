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
package com.redhat.codeready.selenium.core;

import com.google.inject.Module;
import java.util.ArrayList;
import java.util.List;
import org.eclipse.che.selenium.core.CheSeleniumTestHandler;

/** @author Dmytro Nochevnov */
public class CodereadySeleniumTestHandler extends CheSeleniumTestHandler {

  @Override
  public List<Module> getParentModules() {
    List<Module> modules = new ArrayList<>();
    modules.add(new CodereadySeleniumSuiteModule());
    return modules;
  }
}
