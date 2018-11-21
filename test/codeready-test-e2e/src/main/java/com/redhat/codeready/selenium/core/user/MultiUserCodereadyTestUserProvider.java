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
package com.redhat.codeready.selenium.core.user;

import com.google.inject.Inject;
import com.redhat.codeready.selenium.core.client.keycloak.cli.CodereadyKeycloakCliClient;
import java.io.IOException;
import javax.annotation.PreDestroy;
import org.eclipse.che.selenium.core.provider.AdminTestUserProvider;
import org.eclipse.che.selenium.core.provider.TestUserProvider;
import org.eclipse.che.selenium.core.user.AdminTestUser;
import org.eclipse.che.selenium.core.user.MultiUserCheTestUserProvider;
import org.eclipse.che.selenium.core.user.TestUser;
import org.eclipse.che.selenium.core.user.TestUserFactory;
import org.eclipse.che.selenium.core.user.TestUserImpl;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Provides new {@link TestUser} for the Multi User Eclipse Che.
 *
 * @author Dmytro Nochevnov
 */
public class MultiUserCodereadyTestUserProvider implements TestUserProvider {

  private static final Logger LOG = LoggerFactory.getLogger(MultiUserCheTestUserProvider.class);

  private final TestUser testUser;
  private final boolean isNewUser;
  private final CodereadyKeycloakCliClient keycloakCliClient;

  @Inject
  public MultiUserCodereadyTestUserProvider(
      TestUserFactory<TestUserImpl> testUserFactory,
      CodereadyKeycloakCliClient keycloakCliClient,
      AdminTestUserProvider adminTestUserProvider) {
    this.keycloakCliClient = keycloakCliClient;
    TestUserImpl testUser;
    Boolean isNewUser;
    try {
      testUser = keycloakCliClient.createUser(this);
      isNewUser = true;
    } catch (IOException e) {
      LOG.warn(
          "It's impossible to create test user from tests because of error. "
              + "Is going to use admin test user as test user.",
          e);

      isNewUser = false;

      AdminTestUser adminTestUser = adminTestUserProvider.get();
      testUser =
          testUserFactory.create(
              adminTestUser.getName(),
              adminTestUser.getEmail(),
              adminTestUser.getPassword(),
              adminTestUserProvider);

      LOG.info(
          "User name='{}', id='{}' is being used for testing",
          testUser.getName(),
          testUser.getId());
    }

    this.testUser = testUser;
    this.isNewUser = isNewUser;
  }

  @Override
  public TestUser get() {
    return testUser;
  }

  @Override
  @PreDestroy
  public void delete() throws IOException {
    if (isNewUser) {
      keycloakCliClient.delete(testUser);
    }
  }
}
