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

import static com.google.inject.name.Names.named;

import com.google.inject.Key;
import com.google.inject.TypeLiteral;
import com.google.inject.assistedinject.FactoryModuleBuilder;
import org.eclipse.che.api.core.rest.HttpJsonRequestFactory;
import org.eclipse.che.selenium.core.CheSeleniumMultiUserModule;
import org.eclipse.che.selenium.core.CheSeleniumOpenShiftModule;
import org.eclipse.che.selenium.core.CheSeleniumSuiteModule;
import org.eclipse.che.selenium.core.TestExecutionModule;
import org.eclipse.che.selenium.core.client.CheTestUserServiceClient;
import org.eclipse.che.selenium.core.client.CheTestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.client.TestAuthServiceClient;
import org.eclipse.che.selenium.core.client.TestUserServiceClient;
import org.eclipse.che.selenium.core.client.TestUserServiceClientFactory;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClientFactory;
import org.eclipse.che.selenium.core.client.keycloak.KeycloakTestAuthServiceClient;
import org.eclipse.che.selenium.core.configuration.SeleniumTestConfiguration;
import org.eclipse.che.selenium.core.configuration.TestConfiguration;
import org.eclipse.che.selenium.core.pageobject.PageObjectsInjector;
import org.eclipse.che.selenium.core.provider.CheTestApiEndpointUrlProvider;
import org.eclipse.che.selenium.core.provider.CheTestDashboardUrlProvider;
import org.eclipse.che.selenium.core.provider.CheTestIdeUrlProvider;
import org.eclipse.che.selenium.core.provider.CheTestWorkspaceAgentApiEndpointUrlProvider;
import org.eclipse.che.selenium.core.provider.DefaultTestUserProvider;
import org.eclipse.che.selenium.core.provider.TestApiEndpointUrlProvider;
import org.eclipse.che.selenium.core.provider.TestDashboardUrlProvider;
import org.eclipse.che.selenium.core.provider.TestIdeUrlProvider;
import org.eclipse.che.selenium.core.provider.TestWorkspaceAgentApiEndpointUrlProvider;
import org.eclipse.che.selenium.core.requestfactory.CheTestDefaultHttpJsonRequestFactory;
import org.eclipse.che.selenium.core.requestfactory.TestUserHttpJsonRequestFactory;
import org.eclipse.che.selenium.core.requestfactory.TestUserHttpJsonRequestFactoryCreator;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.user.TestUserFactory;
import org.eclipse.che.selenium.core.webdriver.log.WebDriverLogsReaderFactory;
import org.eclipse.che.selenium.core.workspace.CheTestWorkspaceProvider;
import org.eclipse.che.selenium.core.workspace.CheTestWorkspaceUrlResolver;
import org.eclipse.che.selenium.core.workspace.TestWorkspaceProvider;
import org.eclipse.che.selenium.core.workspace.TestWorkspaceUrlResolver;
import org.eclipse.che.selenium.pageobject.PageObjectsInjectorImpl;

/**
 * Guice module per suite.
 *
 * @author Dmytro Nochevnov
 */
public class CodereadySeleniumSuiteModule extends CheSeleniumSuiteModule {

  @Override
  public void configure() {
    TestConfiguration config = new SeleniumTestConfiguration();
    config.getMap().forEach((key, value) -> bindConstant().annotatedWith(named(key)).to(value));

    bind(DefaultTestUser.class).toProvider(DefaultTestUserProvider.class);
    install(
        new FactoryModuleBuilder()
            .build(Key.get(new TypeLiteral<TestUserFactory<DefaultTestUser>>() {}.getType())));

    bind(TestUserServiceClient.class).to(CheTestUserServiceClient.class);

    bind(HttpJsonRequestFactory.class).to(TestUserHttpJsonRequestFactory.class);
    bind(TestUserHttpJsonRequestFactory.class).to(CheTestDefaultHttpJsonRequestFactory.class);

    bind(TestApiEndpointUrlProvider.class).to(CheTestApiEndpointUrlProvider.class);
    bind(TestIdeUrlProvider.class).to(CheTestIdeUrlProvider.class);
    bind(TestDashboardUrlProvider.class).to(CheTestDashboardUrlProvider.class);

    bind(TestWorkspaceAgentApiEndpointUrlProvider.class)
        .to(CheTestWorkspaceAgentApiEndpointUrlProvider.class);

    bind(TestWorkspaceUrlResolver.class).to(CheTestWorkspaceUrlResolver.class);

    install(
        new FactoryModuleBuilder()
            .implement(TestWorkspaceServiceClient.class, CheTestWorkspaceServiceClient.class)
            .build(TestWorkspaceServiceClientFactory.class));

    bind(TestWorkspaceServiceClient.class).to(CheTestWorkspaceServiceClient.class);
    bind(TestWorkspaceProvider.class).to(CheTestWorkspaceProvider.class).asEagerSingleton();

    install(new FactoryModuleBuilder().build(TestUserHttpJsonRequestFactoryCreator.class));
    install(new FactoryModuleBuilder().build(TestUserServiceClientFactory.class));
    install(new FactoryModuleBuilder().build(WebDriverLogsReaderFactory.class));

    bind(PageObjectsInjector.class).to(PageObjectsInjectorImpl.class);

    configureCodereadyRelatedDependencies();
    install(new CheSeleniumMultiUserModule());

    install(new TestExecutionModule());
  }

  private void configureCodereadyRelatedDependencies() {
    bind(TestAuthServiceClient.class).to(KeycloakTestAuthServiceClient.class);
    install(new CheSeleniumOpenShiftModule());
  }
}
