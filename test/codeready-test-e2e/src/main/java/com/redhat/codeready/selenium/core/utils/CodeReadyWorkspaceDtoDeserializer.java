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
package com.redhat.codeready.selenium.core.utils;

import static java.lang.String.format;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import com.redhat.codeready.selenium.core.provider.TestStackAddressReplacementProvider;
import java.util.Optional;
import org.eclipse.che.api.workspace.shared.dto.EnvironmentDto;
import org.eclipse.che.api.workspace.shared.dto.WorkspaceConfigDto;
import org.eclipse.che.commons.annotation.Nullable;
import org.eclipse.che.selenium.core.utils.WorkspaceDtoDeserializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** @author Dmytro Nochevnov */
@Singleton
public class CodeReadyWorkspaceDtoDeserializer extends WorkspaceDtoDeserializer {
  private static final Logger LOG =
      LoggerFactory.getLogger(CodeReadyWorkspaceDtoDeserializer.class);

  @Inject private TestStackAddressReplacementProvider testStackAddressReplacementProvider;

  @Override
  public WorkspaceConfigDto deserializeWorkspaceTemplate(String workspaceTemplateName) {
    WorkspaceConfigDto workspaceConfigDto =
        super.deserializeWorkspaceTemplate(workspaceTemplateName);

    if (testStackAddressReplacementProvider.get().isEmpty()) {
      return workspaceConfigDto;
    }

    String currentStackAddress = readStackAddress(workspaceConfigDto);
    Optional<String> stackAddressReplacement =
        testStackAddressReplacementProvider.get(currentStackAddress);
    stackAddressReplacement.ifPresent(
        stackAddressReplacementValue -> {
          workspaceConfigDto
              .getEnvironments()
              .get("replaced_name")
              .getRecipe()
              .setContent(stackAddressReplacementValue);

          LOG.info(
              format(
                  "Stack address '%s' has been replaced by '%s' in test workspace template '%s'.",
                  currentStackAddress, stackAddressReplacementValue, workspaceTemplateName));
        });

    return workspaceConfigDto;
  }

  @Nullable
  private String readStackAddress(WorkspaceConfigDto workspaceConfigDto) {
    EnvironmentDto workspaceEnv = workspaceConfigDto.getEnvironments().get("replaced_name");
    if (workspaceEnv != null && workspaceEnv.getRecipe() != null) {
      return workspaceEnv.getRecipe().getContent();
    }

    return null;
  }
}
