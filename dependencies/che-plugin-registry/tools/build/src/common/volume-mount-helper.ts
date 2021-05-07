/**********************************************************************
 * Copyright (c) 2020-2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/

import { CheEditorContainerYaml, CheEditorVolume } from '../editor/che-editors-yaml';

import { Container } from './container-helper';
import { injectable } from 'inversify';

export interface ContainerVolumes extends Container {
  volumes?: { mountPath: string; name: string; ephemeral?: boolean }[];
}

/**
 * Map VolumeMount name/path/etc to Volume name/mountPath/etc
 */
@injectable()
export class VolumeMountHelper {
  resolve(container: CheEditorContainerYaml, volumes?: Map<string, CheEditorVolume>): ContainerVolumes {
    if (container.endpoints) {
      delete container.endpoints;
    }
    if (container.volumeMounts) {
      (container as ContainerVolumes).volumes = container.volumeMounts.map(volumeMount => {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const result: any = { name: volumeMount.name, mountPath: volumeMount.path };
        if (volumes) {
          const volume = volumes.get(volumeMount.name);
          if (volume) {
            result.ephemeral = volume.ephemeral;
          }
        }
        return result;
      });
      delete container.volumeMounts;
    }
    return container as ContainerVolumes;
  }
}
