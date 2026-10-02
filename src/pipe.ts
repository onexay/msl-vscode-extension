// SPDX-License-Identifier: Apache-2.0
// Managed pipes: a byte stream to a Unix socket or localhost port inside a
// distro. Each pipe is an `msl --connect <distro> unix=<path>|tcp=<port>`
// process whose stdio is the stream: msld only sets it up, and the msl process
// moves the bytes to and from the VM, so a stuck pipe affects only itself.

import { once } from 'events';
import * as vscode from 'vscode';
import { ChildProcessWithoutNullStreams, spawn } from 'child_process';
import { log, mslPath } from './msl';

export type Target = { unix: string } | { tcp: number };

/** A managed pipe that can also stop reading, for backpressure in tunnels. */
export interface Pipe extends vscode.ManagedMessagePassing {
    pause(): void;
    resume(): void;
}

function describe(t: Target): string {
    return 'unix' in t ? `unix:${t.unix}` : `tcp:${t.tcp}`;
}

export function openPipe(distro: string, target: Target): Promise<Pipe> {
    const arg = 'unix' in target ? `unix=${target.unix}` : `tcp=${target.tcp}`;
    return childPipe(distro, target, spawn(mslPath(), ['--connect', distro, arg], { stdio: 'pipe' }));
}

/** A pipe whose stream is a child process's stdio (msl --connect). */
function childPipe(distro: string, target: Target, child: ChildProcessWithoutNullStreams): Promise<Pipe> {
    const onDidReceiveMessage = new vscode.EventEmitter<Uint8Array>();
    const onDidClose = new vscode.EventEmitter<Error | undefined>();
    const onDidEnd = new vscode.EventEmitter<void>();
    let stderr = '';
    let closed = false;

    child.stdout.on('data', (d: Buffer) => onDidReceiveMessage.fire(d));
    child.stdout.on('end', () => onDidEnd.fire());
    child.stderr.setEncoding('utf8').on('data', (d: string) => (stderr += d));
    child.stdin.on('error', () => {}); // EPIPE after the bridge exits; reported by 'close'
    const close = (err: Error | undefined) => {
        if (!closed) {
            closed = true;
            onDidClose.fire(err);
        }
    };
    child.on('error', (e) => close(e));
    child.on('close', (code) => {
        if (code !== 0 && stderr) {
            log.warn(`[${distro}] pipe ${describe(target)}: ${stderr.trim()}`);
        }
        close(code === 0 ? undefined : new Error(stderr.trim() || `pipe exited with ${code}`));
    });

    return Promise.resolve({
        onDidReceiveMessage: onDidReceiveMessage.event,
        onDidClose: onDidClose.event,
        onDidEnd: onDidEnd.event,
        send: (data: Uint8Array) => {
            if (!closed) {
                child.stdin.write(data);
            }
        },
        end: () => child.stdin.end(),
        drain: async () => {
            if (child.stdin.writableNeedDrain) {
                await Promise.race([once(child.stdin, 'drain'), once(child, 'close')]);
            }
        },
        pause: () => child.stdout.pause(),
        resume: () => child.stdout.resume(),
    });
}
