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
package com.redhat.codeready.selenium.core.provider;

import static com.google.common.base.Charsets.UTF_8;
import static java.lang.String.format;

import com.google.gson.reflect.TypeToken;
import com.google.inject.Provider;
import com.google.inject.Singleton;
import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.util.Collections;
import java.util.Map;
import java.util.Optional;
import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.StringUtils;
import org.eclipse.che.commons.annotation.Nullable;
import org.eclipse.che.commons.json.JsonHelper;
import org.eclipse.che.commons.json.JsonParseException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Provider of Map[stack-image-address-prefix -> new-stack-image-address].
 *
 * <p>Default location of map is "src/test/resources/conf/stack-replacement.json"
 *
 * <p>Example of map to quay.io latest tags could be found in here:
 * "src/test/resources/conf/stack-replacement-quay-latest.json."
 *
 * @author Dmytro Nochevnov
 */
@Singleton
public class TestStackAddressReplacementProvider implements Provider<Map<String, String>> {
  private static final Logger LOG =
      LoggerFactory.getLogger(TestStackAddressReplacementProvider.class);

  private static final String DEFAULT_JAVA_STACK_ADDRESS =
      "registry.redhat.io/codeready-workspaces/stacks-java-rhel8";

  private static final URL PATH_TO_STACK_REPLACEMENT_CONFIG =
      TestStackAddressReplacementProvider.class.getResource("/conf/stack-replacement.json");

  private Map<String, String> stackReplacements;

  @Override
  public Map<String, String> get() {
    if (stackReplacements == null) {
      stackReplacements = read();
    }

    return stackReplacements;
  }

  public Optional<String> get(String oldStackAddress) {
    if (StringUtils.isEmpty(oldStackAddress)) {
      return Optional.empty();
    }

    return get()
        .entrySet()
        .stream()
        .filter((Map.Entry<String, String> entry) -> oldStackAddress.startsWith(entry.getKey()))
        .findFirst()
        .map(Map.Entry::getValue);
  }

  @SuppressWarnings("unchecked")
  private Map<String, String> read() {
    if (PATH_TO_STACK_REPLACEMENT_CONFIG == null) {
      return Collections.emptyMap();
    }

    File stackReplacementConfig = new File(PATH_TO_STACK_REPLACEMENT_CONFIG.getFile());
    try {
      String json = FileUtils.readFileToString(stackReplacementConfig, UTF_8);
      return JsonHelper.fromJson(
          json, Map.class, new TypeToken<Map<String, String>>() {}.getType());
    } catch (IOException | JsonParseException ex) {
      LOG.warn(
          format(
              "Can't read stack address replacement config file '%s' because of error '%s'.",
              stackReplacementConfig, ex.getMessage()),
          ex);

      return Collections.emptyMap();
    }
  }

  @Nullable
  public String getJavaStackReplacement() {
    return get().get(DEFAULT_JAVA_STACK_ADDRESS);
  }
}
