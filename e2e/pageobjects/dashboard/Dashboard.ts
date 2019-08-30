/*********************************************************************
 * Copyright (c) 2019 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 **********************************************************************/
import { inject, injectable } from 'inversify';
import 'reflect-metadata';
import { CLASSES } from '../../inversify.types';
import { By } from 'selenium-webdriver';
import { DriverHelper } from '../../utils/DriverHelper';
import { TestConstants } from '../../TestConstants';

@injectable()
export class Dashboard {
    private static readonly DASHBOARD_BUTTON_CSS: string = '#dashboard-item';
    private static readonly WORKSPACES_BUTTON_CSS: string = '#workspaces-item';
    private static readonly STACKS_BUTTON_CSS: string = '#stacks-item';
    private static readonly FACTORIES_BUTTON_CSS: string = '#factories-item';

    constructor(@inject(CLASSES.DriverHelper) private readonly driverHelper: DriverHelper) { }

    async waitPage(timeout: number = TestConstants.TS_SELENIUM_LOAD_PAGE_TIMEOUT) {
        await this.driverHelper.waitVisibility(By.css(Dashboard.DASHBOARD_BUTTON_CSS), timeout);
        await this.driverHelper.waitVisibility(By.css(Dashboard.WORKSPACES_BUTTON_CSS), timeout);
        await this.driverHelper.waitVisibility(By.css(Dashboard.STACKS_BUTTON_CSS), timeout);
        await this.driverHelper.waitVisibility(By.css(Dashboard.FACTORIES_BUTTON_CSS), timeout);
    }
}
