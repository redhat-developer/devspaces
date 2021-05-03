/**********************************************************************
 * Copyright (c) 2021 Red Hat, Inc.
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 ***********************************************************************/

import { CheEditorContainerYaml, CheEditorVolume } from '../editor/che-editors-yaml';
import { inject, injectable } from 'inversify';

import { CheEditorMetaInfo } from '../editor/che-editors-meta-info';
import { VolumeMountHelper } from './volume-mount-helper';

export interface Container {
  name?: string;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  ports?: any[];
}

export interface Containers {
  containers: Container[];
  initContainers: Container[];
}

@injectable()
export class ContainerHelper {
  @inject(VolumeMountHelper)
  private volumeMountHelper: VolumeMountHelper;

  resolve(editor: CheEditorMetaInfo): Containers {
    const containers: Container[] = [];
    const initContainers: Container[] = [];
    if (editor.components) {
      const volumes = new Map<string, CheEditorVolume>();
      editor.components
        .filter(c => c.name && c.volume && Object.keys(c.volume).length > 0)
        .map(c => c as { name: string; volume: CheEditorVolume })
        .forEach(c => volumes.set(c.name, c.volume));
      editor.components
        .filter(c => c.container)
        .forEach(component => {
          const container = this.volumeMountHelper.resolve(component.container as CheEditorContainerYaml, volumes);
          container.name = component.name;
          if (component.attributes && component.attributes.ports) {
            container.ports = component.attributes.ports;
          }
          if (editor.events && editor.events.preStart) {
            const event = editor.events.preStart.find(e => {
              if (editor.commands) {
                const command = editor.commands.find(c => c.id === e);
                return !!(command && command.apply && component.name === command.apply.component);
              }
              return false;
            });
            if (event) {
              initContainers.push(container);
              return;
            }
          }
          containers.push(container);
        });
    }

    return { containers, initContainers };
  }
}
