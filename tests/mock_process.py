"""Unprivileged fake command; never calls bootc/systemd."""
import json
import os
import resource
import signal
import sys
import time

mode = sys.argv[1]
if mode == 'args':
    print(json.dumps(sys.argv[2:]))
    sys.exit(0)
if mode == 'partial':
    sys.stdout.write('final stdout'); sys.stderr.write('final stderr'); sys.exit(0)
if mode == 'crash':
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0)); os.kill(os.getpid(), signal.SIGSEGV)
if mode == 'long':
    print('started', flush=True); time.sleep(0.4); print('finished'); sys.exit(0)
if mode == 'fail': sys.exit(19)
if mode == 'empty': sys.exit(0)
action = sys.argv[2] if len(sys.argv) > 2 else 'upgrade'
if mode in ('progress', 'progress-fail'):
    # FE_XICO_PROGRESS records as the FE-XicoOS backend relays them from bootc,
    # including a stale repeat and a malformed line that must be ignored.
    def record(seq, state='reporting', event=None):
        return 'FE_XICO_PROGRESS ' + json.dumps(dict(protocol=1, action=action, invocation='a'*32, seq=seq, state=state,
                                                    bootcProtocol='0.1.0', event=event, ignored=0))
    pulling = dict(type='ProgressBytes', task='pulling', description='Pulling Image: sha256:x', id='sha256:x',
                   bytesCached=0, bytes=50, bytesTotal=200, stepsCached=0, steps=1, stepsTotal=4, subtasks=[])
    staging = dict(type='ProgressSteps', task='staging', description='Deploying Image', id='sha256:x', stepsCached=0,
                   steps=3, stepsTotal=3, subtasks=[dict(subtask='cleanup', description='Removing old images', id='cleanup', completed=True)])
    print(record(1, 'waiting'), flush=True); time.sleep(0.1)
    print(record(2, event=pulling), flush=True); time.sleep(0.1)
    print(record(2, event=dict(pulling, bytes=150)), flush=True)      # stale: same seq
    print('FE_XICO_PROGRESS {not json', flush=True)
    print(record(3, event=staging), flush=True); time.sleep(0.1)
    if mode == 'progress-fail':
        sys.exit(7)
    mode = 'staged'
staged = mode in ('download-only', 'locked-lie', 'locked-mislabeled', 'invalid-lock', 'staged', 'duplicate', 'nonzero-result', 'stderr-result')
rollback = action == 'rollback'
host = dict(apiVersion='org.containers.bootc/v1', spec=dict(bootOrder='rollback' if rollback else 'default'),
            status=dict(booted={}, staged={} if staged else None, rollback={} if rollback else None,
                        rollbackQueued=rollback))
result = dict(protocol=1, action=action, invocation='a'*32, started='12',
              outcome='rollback-queued' if rollback else ('staged' if staged else 'up-to-date'),
              rebootRequired=staged or rollback, status=host)
if mode in ('download-only', 'locked-lie', 'locked-mislabeled', 'invalid-lock'):
    host['status']['staged']['downloadOnly'] = True
    result.update(outcome='status' if action == 'status' else 'download-only', rebootRequired=False)
    if mode == 'locked-lie': result['rebootRequired'] = True
    if mode == 'locked-mislabeled': result['outcome'] = 'already-staged'
    if mode == 'invalid-lock': host['status']['staged']['downloadOnly'] = 'false'
if mode == 'malformed': result['protocol'] = 99
if mode == 'contradiction': result['rebootRequired'] = True
line = 'FE_XICO_RESULT ' + json.dumps(result)
print(line, file=sys.stderr if mode == 'stderr-result' else sys.stdout)
if mode == 'duplicate': print(line)
if mode == 'nonzero-result': sys.exit(9)
