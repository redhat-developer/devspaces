/*********************************************************************
 * Copyright (c) 2019 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 **********************************************************************/

import { e2eContainer } from '../../inversify.config';
import { ICrwLoginPage } from '../../pageobjects/login/ICrwLoginPage';
import { IOcpLoginPage } from '../../pageobjects/login/IOcpLoginPage';
import { CLASSES, TYPES } from '../../inversify.types';
import { TestConstants } from '../../TestConstants';
import { Dashboard } from '../../pageobjects/dashboard/Dashboard';
import { OcpLoginPage } from '../../pageobjects/openshift/OcpLoginPage';
import { OcpWebConsolePage } from '../../pageobjects/openshift/OcpWebConsolePage';

const crwLogin: ICrwLoginPage = e2eContainer.get<ICrwLoginPage>(TYPES.CrwLogin);
const ocpLogin: IOcpLoginPage = e2eContainer.get<IOcpLoginPage>(TYPES.OcpLogin);
const ocpLoginPage: OcpLoginPage = e2eContainer.get(CLASSES.OcpLoginPage);
const ocpWebConsole: OcpWebConsolePage = e2eContainer.get(CLASSES.OcpWebConsolePage);
const dashboard: Dashboard = e2eContainer.get(CLASSES.Dashboard);
const projectName: string = TestConstants.TS_INSTALL_CRW_PROJECT_NAME;
const codeReadyOperatorTitle = TestConstants.TS_SELENIUM_CODEREADY_OPERATOR_TITLE;

suite('E2E', async () => {

    suite('Go to OCP and wait console OpenShift', async () => {
        test('Open login page', async () => {
            await ocpLoginPage.openLoginPageOpenShift();
            await ocpLoginPage.waitOpenShiftLoginPage();
        });
        test('Log into OCP', async () => {
            ocpLogin.login();
        });
    });

    suite('Subscribe CodeReady Workspaces operator to defined namespace', async () => {
        test('Open Catalog, select OperatorHub', async () => {
            await ocpWebConsole.waitNavpanelOpenShift();
            await ocpWebConsole.clickOnCatalogListNavPanelOpenShift();
            await ocpWebConsole.clickOnOperatorHubItemNavPanel();
            await ocpWebConsole.waitOperatorHubMainPage();
        });


        test('Select Codeready Workspaces operator and install it', async () => {
            await ocpWebConsole.clickOnCodeReadyWorkspacesOperatorIcon(codeReadyOperatorTitle);
            await ocpWebConsole.clickOnInstallCodeReadyWorkspacesButton();
        });

        test('Select a namespace and subscribe Codeready Workspaces operator', async () => {
            await ocpWebConsole.waitCreateOperatorSubscriptionPage();
            await ocpWebConsole.clickOnDropdownNamespaceListOnSubscriptionPage();
            await ocpWebConsole.waitListBoxNamespacesOnSubscriptionPage();
            await ocpWebConsole.selectDefinedNamespaceOnSubscriptionPage(projectName);
            await ocpWebConsole.clickOnSubscribeButtonOnSubscriptionPage();
        });

        test('Wait the Subscription Overview', async () => {
            await ocpWebConsole.waitSubscriptionOverviewPage();
            await ocpWebConsole.waitUpgradeStatusOnSubscriptionOverviewPage();
            await ocpWebConsole.waitCatalogSourceNameOnSubscriptionOverviewPage(projectName);
        });
    });

    suite('Wait the Codeready Workspaces operator is represented by CSV', async () => {
        test('Select the Installed Operators in the nav panel', async () => {
            await ocpWebConsole.selectInstalledOperatorsOnNavPanel();
        });

        test('Wait installed Codeready Workspaces operator', async () => {
            await ocpWebConsole.waitCodeReadyWorkspacesOperatorLogoName();
            await ocpWebConsole.waitStatusInstalledCodeReadyWorkspacesOperator();
        });
    });

    suite('Create new Che cluster', async () => {
        test('Click on the logo-name CodeReady Workspaces operator', async () => {
            await ocpWebConsole.clickOnCodeReadyWorkspacesOperatorLogoName();
            await ocpWebConsole.waitOverviewCsvCrwOperator();
        });


        test('Click on the Create New, wait CSV yaml', async () => {
            await ocpWebConsole.clickCreateNewCheClusterLink();
            await ocpWebConsole.waitCreateCheClusterYaml();
        });

        test('Create Che Cluster ', async () => {
            await ocpWebConsole.clickOnCreateCheClusterButton();
            await ocpWebConsole.waitResourcesCheClusterTitle();
            await ocpWebConsole.waitResourcesCheClusterTimestamp();
            await ocpWebConsole.clickOnCheClusterResourcesName();
        });
    });

    suite('Check the CodeReady Workspaces is ready', async () => {
        test('Wait Keycloak Admin Console URL', async () => {
            await ocpWebConsole.clickCheClusterOverviewExpandButton();
            await ocpWebConsole.waitKeycloakAdminConsoleUrl(projectName);
        });

        test('Wait CodeReady Workspaces URL', async () => {
            await ocpWebConsole.waitCodeReadyWorkspacesUrl(projectName);
        });
    });

    suite('Log into CodeReady Workspaces', async () => {
        test('Click on the Codeready Workspaces URL ', async () => {
            await ocpWebConsole.clickOnCodeReadyWorkspacesUrl(projectName);
        });

        test('Login to CodeReady Workspaces', async () => {
            await crwLogin.login();
        });

        test('Wait CodeReady Workspaces dashboard', async () => {
            await dashboard.waitPage();
        });
    });
});
