/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/

import * as path from 'path';

import { injectable, postConstruct } from 'inversify';
import simpleGit, { SimpleGit } from 'simple-git';

// Needs to provide the name of the sidecar image for a given directory (like 'java11' or 'go')
@injectable()
export class SidecarDockerImage {
  public static readonly PREFIX_IMAGE: string = 'quay.io/eclipse/che-plugin-sidecar';

  private git: SimpleGit;

  private gitRootDirectory: string;

  constructor() {
    // reduce concurrent processes
    this.git = simpleGit({ maxConcurrentProcesses: 1 });
  }

  @postConstruct()
  async init(): Promise<void> {
    this.gitRootDirectory = await this.git.revparse(['--show-toplevel']);
  }

  async getDockerImageFor(sidecarShortDirectory: string): Promise<string> {
    // Use long hash (and not short hash) as the value may vary across different git implementations and simple-git does not support abbrev parameter
    const format = {
      hash: '%H',
    };
    const fullPathSideCarDirectory = path.resolve(this.gitRootDirectory, 'sidecars', sidecarShortDirectory);

    const logOptions = {
      format,
      // provide the path to the sidecars
      file: fullPathSideCarDirectory,
      // keep only one result
      n: '1',
    };
    const result = await this.git.log(logOptions);
    const latest = result.latest;
    if (!latest) {
      throw new Error(`Unable to find result when executing ${JSON.stringify(logOptions)}`);
    }
    const hash = latest.hash;
    return `${SidecarDockerImage.PREFIX_IMAGE}:${sidecarShortDirectory}-${hash.substring(0, 7)}`;
  }
}
