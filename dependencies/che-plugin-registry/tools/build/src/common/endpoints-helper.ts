/**********************************************************************
 * Copyright (c) 2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/

import { CommonEndpointYaml } from './common-endpoint-yaml';
import { injectable } from 'inversify';

export interface Endpoint {
  public?: boolean;
}

@injectable()
export class EndpointsHelper {
  resolve(endpoint: CommonEndpointYaml): Endpoint {
    const result: Endpoint = endpoint;
    if (endpoint.exposure) {
      result.public = endpoint.exposure === 'public';
      delete endpoint.exposure;
    }
    if (!endpoint.attributes) {
      endpoint.attributes = {};
    }
    const attributes = endpoint.attributes;
    if (attributes.type === 'main') {
      attributes.type = 'ide';
    }
    if (endpoint.protocol) {
      attributes.protocol = endpoint.protocol;
      delete endpoint.protocol;
    }
    if (endpoint.secure !== undefined) {
      attributes.secure = endpoint.secure;
      delete endpoint.secure;
    }
    return result;
  }
}
