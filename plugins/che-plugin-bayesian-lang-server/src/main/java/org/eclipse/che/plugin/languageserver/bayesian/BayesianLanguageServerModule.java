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
package org.eclipse.che.plugin.languageserver.bayesian;

import static com.google.inject.multibindings.MapBinder.newMapBinder;

import com.google.inject.AbstractModule;
import org.eclipse.che.api.languageserver.LanguageServerConfig;
import org.eclipse.che.inject.DynaModule;
import org.eclipse.che.plugin.languageserver.bayesian.server.launcher.BayesianLanguageServerConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** 'Test' Language Server Module */
@DynaModule
public class BayesianLanguageServerModule extends AbstractModule {

  private static final Logger LOGGER = LoggerFactory.getLogger(BayesianLanguageServerModule.class);

  public static final String TXT_LANGUAGE_ID = "text";

  public static final String[] FILE_EXTENSIONS = new String[] {"txt"};

  @Override
  protected void configure() {
    LOGGER.info("Configuring " + this.getClass().getName());

    newMapBinder(binder(), String.class, LanguageServerConfig.class)
        .addBinding("org.eclipse.che.plugin.bayesian.languageserver")
        .to(BayesianLanguageServerConfig.class)
        .asEagerSingleton();
  }
}
