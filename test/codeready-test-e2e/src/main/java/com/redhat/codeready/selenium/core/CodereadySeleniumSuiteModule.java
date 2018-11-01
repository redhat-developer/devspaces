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
import com.redhat.codeready.selenium.core.client.keycloak.cli.CodereadyKeycloakCliCommandExecutor;
import com.redhat.codeready.selenium.core.user.MultiUserCodereadyDefaultTestUserProvider;
import com.redhat.codeready.selenium.core.user.MultiUserCodereadyTestUserProvider;
import org.eclipse.che.api.core.rest.HttpJsonRequestFactory;
import org.eclipse.che.selenium.core.CheSeleniumSuiteModule;
import org.eclipse.che.selenium.core.client.CheTestDefaultOrganizationServiceClient;
import org.eclipse.che.selenium.core.client.CheTestMachineServiceClient;
import org.eclipse.che.selenium.core.client.CheTestUserServiceClient;
import org.eclipse.che.selenium.core.client.CheTestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.client.TestAuthServiceClient;
import org.eclipse.che.selenium.core.client.TestMachineServiceClient;
import org.eclipse.che.selenium.core.client.TestOrganizationServiceClient;
import org.eclipse.che.selenium.core.client.TestOrganizationServiceClientFactory;
import org.eclipse.che.selenium.core.client.TestUserServiceClient;
import org.eclipse.che.selenium.core.client.TestUserServiceClientFactory;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClient;
import org.eclipse.che.selenium.core.client.TestWorkspaceServiceClientFactory;
import org.eclipse.che.selenium.core.client.keycloak.KeycloakTestAuthServiceClient;
import org.eclipse.che.selenium.core.client.keycloak.cli.KeycloakCliCommandExecutor;
import org.eclipse.che.selenium.core.configuration.SeleniumTestConfiguration;
import org.eclipse.che.selenium.core.configuration.TestConfiguration;
import org.eclipse.che.selenium.core.pageobject.PageObjectsInjector;
import org.eclipse.che.selenium.core.provider.AdminTestUserProvider;
import org.eclipse.che.selenium.core.provider.CheTestApiEndpointUrlProvider;
import org.eclipse.che.selenium.core.provider.CheTestDashboardUrlProvider;
import org.eclipse.che.selenium.core.provider.CheTestIdeUrlProvider;
import org.eclipse.che.selenium.core.provider.CheTestWorkspaceAgentApiEndpointUrlProvider;
import org.eclipse.che.selenium.core.provider.DefaultTestUserProvider;
import org.eclipse.che.selenium.core.provider.TestApiEndpointUrlProvider;
import org.eclipse.che.selenium.core.provider.TestDashboardUrlProvider;
import org.eclipse.che.selenium.core.provider.TestIdeUrlProvider;
import org.eclipse.che.selenium.core.provider.TestUserProvider;
import org.eclipse.che.selenium.core.provider.TestWorkspaceAgentApiEndpointUrlProvider;
import org.eclipse.che.selenium.core.requestfactory.CheTestDefaultHttpJsonRequestFactory;
import org.eclipse.che.selenium.core.requestfactory.TestUserHttpJsonRequestFactory;
import org.eclipse.che.selenium.core.requestfactory.TestUserHttpJsonRequestFactoryCreator;
import org.eclipse.che.selenium.core.user.AdminTestUser;
import org.eclipse.che.selenium.core.user.DefaultTestUser;
import org.eclipse.che.selenium.core.user.MultiUserCheAdminTestUserProvider;
import org.eclipse.che.selenium.core.user.TestUser;
import org.eclipse.che.selenium.core.user.TestUserFactory;
import org.eclipse.che.selenium.core.user.TestUserImpl;
import org.eclipse.che.selenium.core.webdriver.DownloadedFileUtil;
import org.eclipse.che.selenium.core.webdriver.DownloadedIntoGridFileUtil;
import org.eclipse.che.selenium.core.webdriver.DownloadedLocallyFileUtil;
import org.eclipse.che.selenium.core.webdriver.UploadIntoGridUtil;
import org.eclipse.che.selenium.core.webdriver.UploadLocallyUtil;
import org.eclipse.che.selenium.core.webdriver.UploadUtil;
import org.eclipse.che.selenium.core.webdriver.log.WebDriverLogsReaderFactory;
import org.eclipse.che.selenium.core.workspace.CheTestOpenshiftWorkspaceLogsReader;
import org.eclipse.che.selenium.core.workspace.CheTestWorkspaceProvider;
import org.eclipse.che.selenium.core.workspace.CheTestWorkspaceUrlResolver;
import org.eclipse.che.selenium.core.workspace.TestWorkspaceLogsReader;
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

    configureUserRelatedDependencies();
    configureCodereadyRelatedDependencies();

    configureTestExecutionModeRelatedDependencies();
  }

  private void configureCodereadyRelatedDependencies() {
    // TODO get to adapt to CodeReady
    bind(TestWorkspaceLogsReader.class).to(CheTestOpenshiftWorkspaceLogsReader.class);
    bind(KeycloakCliCommandExecutor.class).to(CodereadyKeycloakCliCommandExecutor.class);
  }

  private void configureUserRelatedDependencies() {
    // TODO get to adapt to CodeReady
    bind(TestAuthServiceClient.class).to(KeycloakTestAuthServiceClient.class);
    bind(TestMachineServiceClient.class).to(CheTestMachineServiceClient.class);

    bind(DefaultTestUserProvider.class).to(MultiUserCodereadyDefaultTestUserProvider.class);

    bind(TestUser.class).toProvider(TestUserProvider.class);
    bind(TestUserProvider.class).to(MultiUserCodereadyTestUserProvider.class);

    bind(AdminTestUser.class).toProvider(AdminTestUserProvider.class);
    bind(AdminTestUserProvider.class).to(MultiUserCheAdminTestUserProvider.class);

    bind(TestOrganizationServiceClient.class).to(CheTestDefaultOrganizationServiceClient.class);

    install(
        new FactoryModuleBuilder()
            .build(Key.get(new TypeLiteral<TestUserFactory<AdminTestUser>>() {}.getType())));

    install(
        new FactoryModuleBuilder()
            .build(Key.get(new TypeLiteral<TestUserFactory<TestUserImpl>>() {}.getType())));

    install(new FactoryModuleBuilder().build(TestOrganizationServiceClientFactory.class));
  }

  // TODO use CheSeleniumSuiteModule.configureTestExecutionModeRelatedDependencies()
  private void configureTestExecutionModeRelatedDependencies() {
    boolean gridMode = Boolean.valueOf(System.getProperty("grid.mode"));
    if (gridMode) {
      bind(DownloadedFileUtil.class).to(DownloadedIntoGridFileUtil.class);
      bind(UploadUtil.class).to(UploadIntoGridUtil.class);
    } else {
      bind(DownloadedFileUtil.class).to(DownloadedLocallyFileUtil.class);
      bind(UploadUtil.class).to(UploadLocallyUtil.class);
    }
  }
}
