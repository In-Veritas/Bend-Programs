#!/usr/bin/env python3
"""Measure one command without fabricating unavailable energy data."""

import argparse
import json
import os
from pathlib import Path
import platform
import re
import resource
import signal
import subprocess
import sys
import tempfile
import time


CPU_POWER = re.compile(r"CPU Power:\s*([0-9.]+)\s*mW")


def tail(text, lines=20):
    return "\n".join(text.splitlines()[-lines:])


def begin_energy(sample_ms):
    if platform.system() != "Darwin" or not Path("/usr/bin/powermetrics").is_file():
        return None, "powermetrics is unavailable on this platform"
    command = [
        "sudo", "-n", "/usr/bin/powermetrics",
        "--sample-rate", str(sample_ms),
        "--samplers", "cpu_power",
        "--buffer-size", "1",
    ]
    try:
        process = subprocess.Popen(
            command,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except OSError as error:
        return None, f"cannot start powermetrics through sudo -n: {error}"
    time.sleep(min(0.25, sample_ms / 1000))
    if process.poll() is not None:
        stdout, stderr = process.communicate()
        reason = tail(stderr or stdout) or "powermetrics exited before sampling"
        return None, reason
    return process, None


def finish_energy(process, sample_ms):
    if process is None:
        return None
    process.send_signal(signal.SIGINT)
    try:
        stdout, stderr = process.communicate(timeout=15)
    except subprocess.TimeoutExpired:
        process.kill()
        stdout, stderr = process.communicate()
    samples_mw = [float(value) for value in CPU_POWER.findall(stdout)]
    if not samples_mw:
        return {
            "available": False,
            "source": "macOS powermetrics cpu_power",
            "reason": tail(stderr or stdout) or "no CPU Power samples",
        }
    joules = sum(samples_mw) * sample_ms / 1_000_000
    return {
        "available": True,
        "source": "macOS powermetrics cpu_power",
        "scope": "estimated whole-system CPU subsystem; not process energy",
        "sample_interval_ms": sample_ms,
        "sample_count": len(samples_mw),
        "mean_power_watts": sum(samples_mw) / len(samples_mw) / 1000,
        "estimated_cpu_joules": joules,
    }


def run_command(command):
    """Run one command and return output plus that child's exact resource use."""
    with tempfile.TemporaryFile(mode="w+") as stdout_file, \
         tempfile.TemporaryFile(mode="w+") as stderr_file:
        process = subprocess.Popen(
            command,
            text=True,
            stdout=stdout_file,
            stderr=stderr_file,
        )
        if hasattr(os, "wait4"):
            _, status, usage = os.wait4(process.pid, 0)
            process.returncode = os.waitstatus_to_exitcode(status)
        else:
            usage_before = resource.getrusage(resource.RUSAGE_CHILDREN)
            process.wait()
            usage_after = resource.getrusage(resource.RUSAGE_CHILDREN)
            usage = type("Usage", (), {
                "ru_utime": usage_after.ru_utime - usage_before.ru_utime,
                "ru_stime": usage_after.ru_stime - usage_before.ru_stime,
                "ru_maxrss": usage_after.ru_maxrss,
            })()
        stdout_file.seek(0)
        stderr_file.seek(0)
        return process.returncode, stdout_file.read(), stderr_file.read(), usage


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--energy", choices=("auto", "off"), default="auto")
    parser.add_argument("--energy-sample-ms", type=int, default=500)
    parser.add_argument("--stdout-output", type=Path)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        parser.error("a command is required after --")
    if args.energy_sample_ms < 100:
        parser.error("--energy-sample-ms must be at least 100")

    energy_process = None
    energy_reason = "disabled"
    if args.energy == "auto":
        energy_process, energy_reason = begin_energy(args.energy_sample_ms)

    started_wall = time.time()
    started_monotonic = time.monotonic()
    returncode, stdout, stderr, usage = run_command(command)
    elapsed = time.monotonic() - started_monotonic
    energy = finish_energy(energy_process, args.energy_sample_ms)
    if energy is None:
        energy = {
            "available": False,
            "source": "macOS powermetrics cpu_power",
            "reason": energy_reason,
        }

    maximum_resident = usage.ru_maxrss
    if platform.system() != "Darwin":
        maximum_resident *= 1024
    metrics = {
        "time_real_seconds": elapsed,
        "time_user_seconds": usage.ru_utime,
        "time_system_seconds": usage.ru_stime,
        "maximum_resident_bytes": int(maximum_resident),
        "maximum_resident_note": "maximum RSS reported for the measured command",
    }
    report = {
        "schema": 1,
        "command": command,
        "started_unix_seconds": started_wall,
        "elapsed_monotonic_seconds": elapsed,
        "exit_code": returncode,
        "platform": {
            "system": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
            "python": platform.python_version(),
        },
        "metrics": metrics,
        "energy": energy,
        "stdout_tail": tail(stdout),
        "stderr_tail": tail(stderr),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_name(args.output.name + ".tmp")
    temporary.write_text(json.dumps(report, indent=2) + "\n")
    os.replace(temporary, args.output)
    if args.stdout_output is not None:
        args.stdout_output.parent.mkdir(parents=True, exist_ok=True)
        stdout_temporary = args.stdout_output.with_name(args.stdout_output.name + ".tmp")
        stdout_temporary.write_text(stdout)
        os.replace(stdout_temporary, args.stdout_output)
    print(json.dumps(report, indent=2))
    raise SystemExit(returncode)


if __name__ == "__main__":
    main()
