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
package com.redhat.codeready.selenium.core.provider;

import static com.google.common.base.Charsets.UTF_8;
import static java.lang.String.format;

import com.google.gson.reflect.TypeToken;
import com.google.inject.Inject;
import com.google.inject.Provider;
import com.google.inject.Singleton;
import com.google.inject.name.Named;
import java.io.File;
import java.io.IOException;
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
 * <p>To use container path overrides, export this environment variable
 * <b>STACK_REPLACEMENT_CONFIG_FILE</b>, which should point to a json file with a map of overrides
 * for the default containers.
 *
 * <p>Example of map to quay.io latest tags could be found in here:
 * test/resources/conf/stack-replacement-quay-latest.json.
 *
 * <p>It could be defined as following:
 *
 * <p><code>
 * export STACK_REPLACEMENT_CONFIG_FILE=test/resources/conf/stack-replacement-quay-latest.json
 * </code>
 *
 * @author Dmytro Nochevnov
 */
@Singleton
public class TestStackAddressReplacementProvider implements Provider<Map<String, String>> {
  private static final Logger LOG =
      LoggerFactory.getLogger(TestStackAddressReplacementProvider.class);

  private static final String DEFAULT_JAVA_STACK_ADDRESS =
      "registry.access.redhat.com/codeready-workspaces/stacks-java";

  private Map<String, String> stackReplacements;

  @Inject(optional = true)
  @Named("env.stack.replacement.config.file")
  private String stackReplacementConfigFile;

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
    if (stackReplacementConfigFile == null) {
      return Collections.emptyMap();
    }

    File configFile = new File(stackReplacementConfigFile);
    if (!configFile.exists()) {
      return Collections.emptyMap();
    }

    try {
      String json = FileUtils.readFileToString(configFile, UTF_8);
      return JsonHelper.fromJson(
          json, Map.class, new TypeToken<Map<String, String>>() {}.getType());
    } catch (IOException | JsonParseException ex) {
      LOG.warn(
          format(
              "Can't read stack address replacement config file '%s' because of error '%s'.",
              stackReplacementConfigFile, ex.getMessage()),
          ex);

      return Collections.emptyMap();
    }
  }

  @Nullable
  public String getJavaStackReplacement() {
    return get().get(DEFAULT_JAVA_STACK_ADDRESS);
  }
}
