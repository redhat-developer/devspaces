
/*********************************************************************
 * Copyright (c) 2019 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 **********************************************************************/

const TYPES = {
    Driver: Symbol.for('Driver'),
    CrwLogin: Symbol.for('CrwLogin'),
    OcpLogin: Symbol.for('OcpLogin')
};

const CLASSES = {
    DriverHelper: 'DriverHelper',
    Dashboard: 'Dashboard',
    ScreenCatcher: 'ScreenCatcher',
    OcpLoginPage: 'OcpLoginPage',
    OcpWebConsolePage: 'OcpWebConsolePage'
};

export { TYPES, CLASSES };
