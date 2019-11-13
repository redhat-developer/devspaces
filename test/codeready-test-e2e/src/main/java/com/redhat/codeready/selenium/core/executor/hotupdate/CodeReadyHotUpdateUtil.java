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
package com.redhat.codeready.selenium.core.executor.hotupdate;

import com.google.inject.Inject;
import com.google.inject.Singleton;
import java.io.IOException;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeoutException;
import org.eclipse.che.selenium.core.client.TestUserPreferencesServiceClient;
import org.eclipse.che.selenium.core.executor.OpenShiftCliCommandExecutor;
import org.eclipse.che.selenium.core.executor.hotupdate.HotUpdateUtil;
import org.eclipse.che.selenium.core.utils.WaitUtils;

/**
 * Specific for CodeReady Workspaces methods.
 *
 * @author Dmytro Nochevnov
 */
@Singleton
public class CodeReadyHotUpdateUtil extends HotUpdateUtil {
  private static final int TIMEOUT_FOR_FINISH_UPDATE_IN_SECONDS = 600;
  private static final String PODS_LIST_COMMAND = "get pods | awk 'NR > 1 {print $1}'";
  private static final String COMMAND_TO_GET_DEPLOYMENT_VERSION =
      "status | grep \"deployment #\" | awk 'NR == 1 {print $2}' | sed \"s/#//\"";
  private static final String UPDATE_COMMAND_TEMPLATE =
      "patch deployment %s -p \"{\\\"spec\\\": {\\\"template\\\": {\\\"spec\\\":{\\\"terminationGracePeriodSeconds\\\":35}}}}\"";

  @Inject
  public CodeReadyHotUpdateUtil(
      OpenShiftCliCommandExecutor openShiftCliCommandExecutor,
      TestUserPreferencesServiceClient testUserPreferencesServiceClient) {
    super(openShiftCliCommandExecutor, testUserPreferencesServiceClient);
  }

  @Override
  public void waitFullMasterPodUpdate(int masterRevisionBeforeUpdate, int timeoutInSec)
      throws TimeoutException, InterruptedException, ExecutionException {
    waitMasterPodRevision(masterRevisionBeforeUpdate, timeoutInSec);
  }

  /**
   * Waits until update is finished by checking that only single master pod is present and it has
   * incremented {@code masterVersionBeforeUpdate} number in name.
   *
   * @param masterRevisionBeforeUpdate - revision of the master pod before updating.
   * @throws Exception
   */
  @Override
  public void waitFullMasterPodUpdate(int masterRevisionBeforeUpdate) throws Exception {
    waitFullMasterPodUpdate(masterRevisionBeforeUpdate, TIMEOUT_FOR_FINISH_UPDATE_IN_SECONDS);
  }

  /**
   * Waits during {@code timeoutInSec} until master pod has a specified {@code expectedRevision}.
   *
   * @param expectedRevision revision of the master pod.
   * @param timeoutInSec - waiting time in seconds.
   */
  @Override
  public void waitMasterPodRevision(int expectedRevision, int timeoutInSec)
      throws TimeoutException, InterruptedException, ExecutionException {
    WaitUtils.waitSuccessCondition(() -> expectedRevision == getMasterPodRevision(), timeoutInSec);
  }

  /**
   * Waits until master pod has a specified {@code expectedRevision}.
   *
   * @param expectedRevision master pod revision.
   */
  @Override
  public void waitMasterPodRevision(int expectedRevision)
      throws TimeoutException, InterruptedException, ExecutionException {
    waitMasterPodRevision(expectedRevision, TIMEOUT_FOR_FINISH_UPDATE_IN_SECONDS);
  }

  /**
   * Performs CLI command for master pod updating.
   *
   * @throws Exception
   */
  @Override
  public void executeMasterPodUpdateCommand() throws Exception {
    openShiftCliCommandExecutor.execute(UPDATE_COMMAND_TEMPLATE);
  }

  /** Performs GET request to master pod API for checking its availability. */
  @Override
  public void checkMasterPodAvailabilityByPreferencesRequest() {
    try {
      testUserPreferencesServiceClient.getPreferences();
    } catch (Exception ex) {
      throw new RuntimeException("Master POD is not available", ex);
    }
  }

  /**
   * Performs CLI request to the master pod for getting its revision.
   *
   * @return revision of the master pod.
   */
  @Override
  public int getMasterPodRevision() {
    try {
      return Integer.parseInt(
          openShiftCliCommandExecutor.execute(COMMAND_TO_GET_DEPLOYMENT_VERSION));
    } catch (IOException ex) {
      throw new RuntimeException(ex.getLocalizedMessage(), ex);
    }
  }

  @Override
  public String getMasterPodName() {
    return "";
  }
}
