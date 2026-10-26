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
