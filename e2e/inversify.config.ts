/*********************************************************************
 * Copyright (c) 2019 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 **********************************************************************/
import { Container } from 'inversify';
import { IDriver } from './driver/IDriver';
import { TYPES, CLASSES } from './inversify.types';
import { ChromeDriver } from './driver/ChromeDriver';
import { DriverHelper } from './utils/DriverHelper';
import { ICrwLoginPage } from './pageobjects/login/ICrwLoginPage';
import { IOcpLoginPage } from './pageobjects/login/IOcpLoginPage';
import { Dashboard } from './pageobjects/dashboard/Dashboard';
import { ScreenCatcher } from './utils/ScreenCatcher';
import { MultiUserLoginPage } from './pageobjects/login/MultiUserLoginPage';
import { OcpLoginPage } from './pageobjects/openshift/OcpLoginPage';
import { OcpWebConsolePage } from './pageobjects/openshift/OcpWebConsolePage';
import { OcpLoginByTempAdmin } from './pageobjects/login/OcpLoginByTempAdmin';

const e2eContainer = new Container();

e2eContainer.bind<IDriver>(TYPES.Driver).to(ChromeDriver).inSingletonScope();

e2eContainer.bind<IOcpLoginPage>(TYPES.OcpLogin).to(OcpLoginByTempAdmin).inSingletonScope();

e2eContainer.bind<ICrwLoginPage>(TYPES.CrwLogin).to(MultiUserLoginPage).inSingletonScope();
e2eContainer.bind<DriverHelper>(CLASSES.DriverHelper).to(DriverHelper).inSingletonScope();
e2eContainer.bind<Dashboard>(CLASSES.Dashboard).to(Dashboard).inSingletonScope();
e2eContainer.bind<ScreenCatcher>(CLASSES.ScreenCatcher).to(ScreenCatcher).inSingletonScope();
e2eContainer.bind<OcpLoginPage>(CLASSES.OcpLoginPage).to(OcpLoginPage).inSingletonScope();
e2eContainer.bind<OcpWebConsolePage>(CLASSES.OcpWebConsolePage).to(OcpWebConsolePage).inSingletonScope();

export { e2eContainer };
