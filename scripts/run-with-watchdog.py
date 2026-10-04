#!/usr/bin/env python3
"""Stop builds with no output or excessive elapsed time; preserve streamed logs."""
import argparse
import os
import selectors
import signal
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--idle-seconds', type=float, default=600)
    parser.add_argument('--max-seconds', type=float, default=5400)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command or args.idle_seconds <= 0 or args.max_seconds <= 0:
        parser.error('Supply a command and positive timeouts')
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               start_new_session=True)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    started = activity = time.monotonic()
    timed_out = False
    try:
        while selector.get_map():
            events = selector.select(timeout=0.2)
            for key, _ in events:
                chunk = os.read(key.fd, 65536)
                if chunk:
                    sys.stdout.buffer.write(chunk)
                    sys.stdout.buffer.flush()
                    activity = time.monotonic()
                else:
                    selector.unregister(key.fileobj)
            now = time.monotonic()
            if process.poll() is not None and not events:
                break
            if process.poll() is None and (now - activity > args.idle_seconds or now - started > args.max_seconds):
                print('\n::error::Build watchdog: idle or wall-clock timeout; cancelling.', flush=True)
                timed_out = True
                break
        if timed_out:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
        return 124 if timed_out else process.wait()
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
        selector.close()


if __name__ == '__main__':
    sys.exit(main())
