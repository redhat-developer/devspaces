/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/
import { inject, injectable } from 'inversify';

import { Deferred } from '../util/deferred';
import { VsixDownload } from './vsix-download';
import { VsixInfo } from './vsix-info';
import { VsixReadInfo } from './vsix-read-info';
import { VsixUnpack } from './vsix-unpack';

/**
 * Analyze a given vsix URL
 */
@injectable()
export class VsixUrlAnalyzer {
  @inject(VsixDownload)
  private vsixDownload: VsixDownload;

  @inject(VsixUnpack)
  private vsixUnpack: VsixUnpack;

  @inject(VsixReadInfo)
  private vsixReadInfo: VsixReadInfo;

  private deferredPromises: Map<string, Deferred<void>>;

  constructor() {
    this.deferredPromises = new Map();
  }

  async analyze(vsixInfo: VsixInfo): Promise<void> {
    let deferred = this.deferredPromises.get(vsixInfo.uri);
    if (!deferred) {
      deferred = new Deferred<void>();
      this.deferredPromises.set(vsixInfo.uri, deferred);
    } else {
      // wait that other analyze finish
      await deferred.promise;
    }

    // need to download
    await this.vsixDownload.download(vsixInfo);

    // need to unpack
    await this.vsixUnpack.unpack(vsixInfo);

    // read package.json file
    await this.vsixReadInfo.read(vsixInfo);

    // resolve to let others analyze
    deferred.resolve();
  }
}
