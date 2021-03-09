/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/

import { injectable } from 'inversify';

export interface ContainerVolumes {
  volumes?: { mountPath: string; name: string; ephemeral?: boolean }[];
}

export interface ContainerVolumeMounts {
  volumeMounts?: { path: string; name: string; ephemeral?: boolean }[];
}

/**
 * Map VolumeMount name/path/etc to Volume name/mountPath/etc
 */
@injectable()
export class VolumeMountHelper {
  resolve(container: ContainerVolumeMounts): ContainerVolumes {
    if (container.volumeMounts) {
      (container as ContainerVolumes).volumes = container.volumeMounts.map(volumeMount => {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const volume: any = { name: volumeMount.name, mountPath: volumeMount.path };
        if (volumeMount.ephemeral) {
          volume.ephemeral = volumeMount.ephemeral;
        }
        return volume;
      });
      delete container.volumeMounts;
    }
    return container as ContainerVolumes;
  }
}
