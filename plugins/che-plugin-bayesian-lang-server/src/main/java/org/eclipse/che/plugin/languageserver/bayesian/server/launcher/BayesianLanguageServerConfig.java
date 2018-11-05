/*
 * Copyright (c) 2016-2018 Red Hat, Inc.
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Contributors:
 *   Red Hat, Inc. - initial API and implementation
 */
package org.eclipse.che.plugin.languageserver.bayesian.server.launcher;

import static org.slf4j.LoggerFactory.getLogger;

import com.google.common.collect.ImmutableMap;
import com.google.common.collect.ImmutableSet;
import com.google.inject.Inject;
import com.google.inject.Singleton;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;
import java.util.Set;
import org.eclipse.che.api.languageserver.DefaultInstanceProvider;
import org.eclipse.che.api.languageserver.LanguageServerConfig;
import org.eclipse.che.api.languageserver.ProcessCommunicationProvider;
import org.eclipse.che.plugin.json.inject.JsonModule;
import org.eclipse.che.plugin.languageserver.bayesian.BayesianLanguageServerModule;
import org.slf4j.Logger;

/**
 * @author Evgen Vidolob
 * @author Anatolii Bazko
 */
@Singleton
public class BayesianLanguageServerConfig implements LanguageServerConfig {
  private static final Logger LOG = getLogger(BayesianLanguageServerConfig.class);

  private final Path launchScript;

  @Inject
  public BayesianLanguageServerConfig() {

    launchScript = Paths.get(System.getenv("HOME"), "che/ls-bayesian/launch.sh");
  }

  @Override
  public RegexProvider getRegexpProvider() {
    return new RegexProvider() {
      @Override
      public Map<String, String> getLanguageRegexes() {
        return ImmutableMap.<String, String>builder()
            .put(BayesianLanguageServerModule.TXT_LANGUAGE_ID, ".*requirements\\.txt")
            .put(JsonModule.LANGUAGE_ID, ".*package\\.json")
            .put("pom", ".*pom\\.xml")
            .build();
      }

      @Override
      public Set<String> getFileWatchPatterns() {
        return ImmutableSet.of();
      }
    };
  }

  @Override
  public CommunicationProvider getCommunicationProvider() {

    String launchCommand =
        "export THREE_SCALE_USER_TOKEN=\"250f7573417ff52aee50728f698ecd96\" && "
            + "export RECOMMENDER_API_URL=\"https://friendly_system_service-2445582075730.staging.gw.apicast.io/api/v1\" && "
            + launchScript.toString();

    ProcessBuilder processBuilder = new ProcessBuilder("/bin/bash", "-c", launchCommand);
    processBuilder.redirectInput(ProcessBuilder.Redirect.PIPE);
    processBuilder.redirectOutput(ProcessBuilder.Redirect.PIPE);
    processBuilder.redirectError(ProcessBuilder.Redirect.INHERIT);

    return new ProcessCommunicationProvider(
        processBuilder, "org.eclipse.che.plugin.bayesian.languageserver");
  }

  @Override
  public InstanceProvider getInstanceProvider() {
    return DefaultInstanceProvider.getInstance();
  }

  @Override
  public InstallerStatusProvider getInstallerStatusProvider() {
    return new InstallerStatusProvider() {
      @Override
      public boolean isSuccessfullyInstalled() {
        return launchScript.toFile().exists();
      }

      @Override
      public String getCause() {
        return isSuccessfullyInstalled() ? null : "Launch script file does not exist";
      }
    };
  }
}
