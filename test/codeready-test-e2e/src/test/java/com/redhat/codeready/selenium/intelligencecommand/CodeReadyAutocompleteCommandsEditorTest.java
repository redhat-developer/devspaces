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
package com.redhat.codeready.selenium.intelligencecommand;

import org.eclipse.che.selenium.intelligencecommand.AutocompleteCommandsEditorTest;

/** @author Aleksandr Shmaraev */
public class CodeReadyAutocompleteCommandsEditorTest extends AutocompleteCommandsEditorTest {

  @Override
  protected void checkItemsInAutocompleteContainer() {
    commandsEditor.typeTextIntoEditor("server.e");
    commandsEditor.launchAutocompleteAndWaitContainer();

    String[] autocompleteItems = {
      "${server.eap}", "${server.eap-debug}", "${server.exec-agent/ws}"
    };

    for (String autocompleteItem : autocompleteItems) {
      commandsEditor.waitTextIntoAutocompleteContainer(autocompleteItem);
    }
  }

  @Override
  protected void waitTextInMacrosForm() {
    commandsEditor.selectAutocompleteProposal("ap}");
    commandsEditor.waitTextIntoDescriptionMacrosForm("Returns address of the eap server");
  }

  @Override
  protected void launchAutocompleteAndWaitText() {
    commandsEditor.typeTextIntoEditor("server.eap-d");
    commandsEditor.launchAutocomplete();
    commandsEditor.waitTextIntoEditor("${server.eap-debug}");
  }

  @Override
  protected void typeTextInEditorAndLaunchAutocomplete() {
    commandsEditor.typeTextIntoEditor("server.wsagent");
    commandsEditor.launchAutocompleteAndWaitContainer();
  }
}
