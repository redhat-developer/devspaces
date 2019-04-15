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
package com.redhat.codeready.selenium.core;

import static com.google.common.base.Charsets.UTF_8;

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

/**
 * Provider of Map[stack-image-address-prefix -> new-stack-image-address].
 *
 * <p>Map has been stored in json file, path to which is read from environment variable
 * "STACK_REPLACEMENT_CONFIG_FILE" with content like the follow: {
 * "registry.access.redhat.com/codeready-workspaces-beta/stacks-java-rhel8":
 * "quay.io/crw/stacks-java-rhel8:1.1-1",
 * "registry.access.redhat.com/codeready-workspaces/stacks-cpp": "quay.io/crw/stacks-cpp:1.1-9" }
 *
 * @author Dmytro Nochevnov
 */
@Singleton
public class TestStackAddressReplacementProvider implements Provider<Map<String, String>> {
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
      return Collections.emptyMap();
    }
  }

  @Nullable
  public String getJavaStackReplacement() {
    return get().get(DEFAULT_JAVA_STACK_ADDRESS);
  }
}
