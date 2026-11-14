import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import time


SCRIPT = Path(__file__).with_name('telegram-priority.sh')


def save(path, state):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(state))
    temporary.replace(path)


def playerctl(path, case, args):
    state = json.loads(path.read_text())
    if args == ['--list-all']:
        print('fixture')
        return 0
    assert args[:2] == ['-p', 'fixture'], args
    command = args[2]
    if command == 'status':
        if state.get('paused_at') and time.monotonic() - state['paused_at'] < 0.2:
            print('Playing')
        elif case == 'status-error' and state.get('paused_at') and not state.get('status_failed'):
            state['status_failed'] = True
            save(path, state)
            return 1
        else:
            print(state['status'])
    elif command == 'metadata':
        if (case == 'missing-before' and not state.get('paused_at')) or (
            case == 'missing-after' and state.get('paused_at')
        ):
            return 1
        print('/track/other' if case == 'changed-track' and state.get('paused_at') else '/track/original')
    elif command == 'pause':
        state['pause_attempted'] = True
        if case == 'pause-error':
            save(path, state)
            return 1
        state.update(status='Paused', paused_at=time.monotonic())
        save(path, state)
    elif command == 'play':
        state['play_attempts'] = state.get('play_attempts', 0) + 1
        if case == 'play-error' and state['play_attempts'] == 1:
            save(path, state)
            return 1
        state['status'] = 'Playing'
        save(path, state)
    else:
        raise AssertionError(args)
    return 0


def pw_dump(path, media_class):
    node = {
        'id': 2,
        'type': 'PipeWire:Interface:Node',
        'info': {
            'state': 'running',
            'props': {'client.id': 1, 'media.class': media_class},
        },
    }
    print(json.dumps([
        {'id': 1, 'type': 'PipeWire:Interface:Client',
         'info': {'props': {'application.process.binary': '.AyuGram-wrapped'}}},
        node,
    ]), flush=True)
    deadline = time.monotonic() + 3
    while not json.loads(path.read_text()).get('pause_attempted'):
        if time.monotonic() > deadline:
            raise AssertionError('Telegram did not pause the playing player')
        time.sleep(0.01)
    time.sleep(0.3)
    print(json.dumps([{'id': 2, 'info': None}]), flush=True)
    time.sleep(1.3)


def test_telegram_priority():
    with tempfile.TemporaryDirectory(prefix='telegram-priority-test-') as directory:
        root = Path(directory)
        for command in ('playerctl', 'pw-dump'):
            wrapper = root / command
            wrapper.write_text(
                '#!/bin/sh\nexec ' + shlex.join([sys.executable, str(Path(__file__).resolve()), command])
                + ' "$@"\n'
            )
            wrapper.chmod(0o755)
        for case in ('async-pause', 'missing-before', 'missing-after', 'status-error',
                     'play-error', 'changed-track', 'pause-error'):
            state_path = root / 'state.json'
            save(state_path, {'status': 'Playing'})
            media_class = 'Stream/Input/Audio' if case == 'missing-after' else 'Stream/Output/Audio'
            result = subprocess.run(
                ['bash', '-euo', 'pipefail', str(SCRIPT)],
                env={**os.environ, 'PATH': str(root) + os.pathsep + os.environ['PATH'],
                     'PRIORITY_TEST_STATE': str(state_path), 'PRIORITY_TEST_CASE': case,
                     'PRIORITY_TEST_CLASS': media_class},
                capture_output=True, text=True, timeout=8,
            )
            assert result.returncode == 0, (case, result.stdout, result.stderr)
            state = json.loads(state_path.read_text())
            if case in ('changed-track', 'pause-error'):
                assert not state.get('play_attempts'), (case, state)
            else:
                assert state['status'] == 'Playing', (case, state, result.stderr)
                assert state['play_attempts'] == (2 if case == 'play-error' else 1), (case, state)
            print('OK:', case)


if __name__ == '__main__':
    if len(sys.argv) == 1:
        test_telegram_priority()
    elif sys.argv[1] == 'playerctl':
        sys.exit(playerctl(Path(os.environ['PRIORITY_TEST_STATE']),
                           os.environ['PRIORITY_TEST_CASE'], sys.argv[2:]))
    elif sys.argv[1] == 'pw-dump':
        pw_dump(Path(os.environ['PRIORITY_TEST_STATE']), os.environ['PRIORITY_TEST_CLASS'])
    else:
        raise AssertionError(sys.argv[1:])
