#!/usr/bin/env python3
"""Measure one command: time, memory, GPU and CPU energy, with an idle baseline.

Usage:
  energy_bench.py [options] -- CMD [ARGS...]

The command runs inside its own memory-capped cgroup scope (`capped`, i.e.
systemd-run --scope in bendwork.slice) while this process holds the shared
bench lock. Measured (stdlib only, no root needed except for RAPL):

  * wall / user / sys seconds of the command tree (inner helper, wait4 +
    RUSAGE_CHILDREN), and the outer wall including scope start-up;
  * peak memory: cgroup `memory.peak` of the command's scope (whole process
    tree, includes page cache and the ~10 MB inner helper) and the largest
    single-process max RSS (ru_maxrss of the children);
  * GPU: NVML total-energy counter (mJ) before/after, and every 100 ms the
    device memory used, utilisation (gpu/memory %), power, and the memory
    used by processes of the command's scope (nvmlDeviceGetComputeRunningProcesses);
  * CPU: every intel-rapl / intel-rapl-mmio domain `energy_uj`, sampled every
    100 ms with wraparound via `max_energy_range_uj`; reported unavailable
    (never estimated) when not readable;
  * an idle baseline of `--baseline-seconds` taken right before the run with
    the lock held, giving baseline power; net energy = raw energy -
    baseline power x run duration (both raw and net are reported);
  * `uptime` before and after, exit status, sha256 of each `--output` file.

One JSON object is printed per run (JSON lines) and appended to `--jsonl`.
"""
import argparse
import ctypes
import fcntl
import hashlib
import json
import os
from pathlib import Path
import resource
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time

LOCK = os.environ.get('BENCH_LOCK') or str(Path(__file__).resolve().parents[1] / '.work' / 'bench.lock')
CAPPED_SH = Path(__file__).resolve().parent / 'capped.sh'
CGROOT = Path('/sys/fs/cgroup')
POWERCAP = Path('/sys/class/powercap')
PERIOD = 0.1


# ---------------------------------------------------------------- inner mode
def inner(result_path, timeout, cmd):
    """Runs inside the capped scope: spawn CMD, wait, read the scope's memory.peak."""
    cg = Path(open('/proc/self/cgroup').read().strip().split('::', 1)[1])
    Path(result_path + '.cg').write_text(str(cg))
    t0 = time.monotonic()
    p = subprocess.Popen(cmd, start_new_session=True)
    status = None
    try:
        status = p.wait(timeout=timeout if timeout > 0 else None)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, signal.SIGKILL)
        p.wait()
        status = 'timeout'
    t1 = time.monotonic()
    ru = resource.getrusage(resource.RUSAGE_CHILDREN)
    def rd(name):
        try:
            return (CGROOT / cg.relative_to('/') / name).read_text()
        except OSError:
            return None
    peak = rd('memory.peak')
    events = rd('memory.events') or ''
    stat = rd('memory.stat') or ''
    anon_peakless = {k: int(v) for k, v in (l.split() for l in stat.splitlines()) if k in ('anon', 'file')}
    Path(result_path).write_text(json.dumps({
        'returncode': status if isinstance(status, int) else None,
        'timed_out': status == 'timeout',
        'start_monotonic': t0, 'end_monotonic': t1,
        'wall_seconds': t1 - t0,
        'user_seconds': ru.ru_utime, 'sys_seconds': ru.ru_stime,
        'max_rss_kib_largest_process': ru.ru_maxrss,
        'cgroup': str(cg),
        'cgroup_memory_peak_bytes': int(peak) if peak else None,
        'cgroup_memory_events': {k: int(v) for k, v in (l.split() for l in events.splitlines())},
        'cgroup_memory_at_exit': anon_peakless,
    }))
    return 0


# ---------------------------------------------------------------- NVML
class _Mem(ctypes.Structure):
    _fields_ = [('total', ctypes.c_ulonglong), ('free', ctypes.c_ulonglong), ('used', ctypes.c_ulonglong)]

class _Util(ctypes.Structure):
    _fields_ = [('gpu', ctypes.c_uint), ('memory', ctypes.c_uint)]

class _Proc(ctypes.Structure):  # nvmlProcessInfo_v2/v3 layout
    _fields_ = [('pid', ctypes.c_uint), ('usedGpuMemory', ctypes.c_ulonglong),
                ('gpuInstanceId', ctypes.c_uint), ('computeInstanceId', ctypes.c_uint)]

class NVML:
    def __init__(self, index=0):
        self.ok = False
        self.has_energy = False
        self.error = None
        try:
            lib = ctypes.CDLL('libnvidia-ml.so.1')
            if lib.nvmlInit_v2() != 0:
                raise OSError('nvmlInit_v2 failed')
            h = ctypes.c_void_p()
            if lib.nvmlDeviceGetHandleByIndex_v2(index, ctypes.byref(h)) != 0:
                raise OSError('no GPU %d' % index)
            self.lib, self.h = lib, h
            name = ctypes.create_string_buffer(96)
            lib.nvmlDeviceGetName(h, name, 96)
            self.name = name.value.decode()
            drv = ctypes.create_string_buffer(96)
            lib.nvmlSystemGetDriverVersion(drv, 96)
            self.driver = drv.value.decode()
            self.ok = True
            # Some drivers (e.g. WSL2) lack the total-energy counter; then energy is
            # integrated from nvmlDeviceGetPowerUsage samples (see Sampler).
            self.has_energy = self.energy_mj() is not None
            if not self.has_energy:
                self.error = 'nvmlDeviceGetTotalEnergyConsumption unsupported: integrating power samples'
        except OSError as e:
            self.error = str(e)

    def energy_mj(self):
        v = ctypes.c_ulonglong()
        return v.value if self.lib.nvmlDeviceGetTotalEnergyConsumption(self.h, ctypes.byref(v)) == 0 else None

    def state(self):
        """Power limits and clock-event (throttle) reasons: laptops cap the board
        (e.g. 20 W instead of 80 W on a flat battery), which invalidates GPU cells."""
        u, ull = ctypes.c_uint(), ctypes.c_ulonglong()
        st = {}
        if self.lib.nvmlDeviceGetEnforcedPowerLimit(self.h, ctypes.byref(u)) == 0:
            st['enforced_power_limit_w'] = u.value / 1000
        if self.lib.nvmlDeviceGetPowerManagementDefaultLimit(self.h, ctypes.byref(u)) == 0:
            st['default_power_limit_w'] = u.value / 1000
        f = getattr(self.lib, 'nvmlDeviceGetCurrentClocksEventReasons', None) or \
            getattr(self.lib, 'nvmlDeviceGetCurrentClocksThrottleReasons', None)
        if f is not None and f(self.h, ctypes.byref(ull)) == 0:
            st['clock_event_reasons'] = hex(ull.value)
        if self.lib.nvmlDeviceGetPerformanceState(self.h, ctypes.byref(u)) == 0:
            st['pstate'] = u.value
        return st

    def sample(self, pids):
        m, u, pw = _Mem(), _Util(), ctypes.c_uint()
        s = {}
        if self.lib.nvmlDeviceGetMemoryInfo(self.h, ctypes.byref(m)) == 0:
            s['mem_used'] = m.used
        if self.lib.nvmlDeviceGetUtilizationRates(self.h, ctypes.byref(u)) == 0:
            s['util_gpu'], s['util_mem'] = u.gpu, u.memory
        if self.lib.nvmlDeviceGetPowerUsage(self.h, ctypes.byref(pw)) == 0:
            s['power_mw'] = pw.value
        if self.lib.nvmlDeviceGetClockInfo(self.h, 1, ctypes.byref(pw)) == 0:  # NVML_CLOCK_SM
            s['sm_mhz'] = pw.value
        own = 0
        s['foreign'] = set()
        if True:
            for fn in ('nvmlDeviceGetComputeRunningProcesses_v3', 'nvmlDeviceGetComputeRunningProcesses_v2'):
                f = getattr(self.lib, fn, None)
                if f is None:
                    continue
                n = ctypes.c_uint(64)
                arr = (_Proc * 64)()
                if f(self.h, ctypes.byref(n), arr) == 0:
                    own = sum(arr[i].usedGpuMemory for i in range(n.value)
                              if arr[i].pid in pids and arr[i].usedGpuMemory < (1 << 62))
                    s['foreign'] = {arr[i].pid for i in range(n.value) if arr[i].pid not in pids}
                break
        s['own_mem'] = own
        return s


# ---------------------------------------------------------------- RAPL
class RAPL:
    """All readable intel-rapl* domains; accumulates deltas with wraparound."""
    def __init__(self):
        self.domains, self.unreadable = {}, []
        for d in sorted(POWERCAP.glob('intel-rapl*:*')):
            f = d / 'energy_uj'
            if not f.exists():
                continue
            try:
                name = (d / 'name').read_text().strip()
                rng = int((d / 'max_energy_range_uj').read_text())
                v = int(f.read_text())
            except (OSError, ValueError) as e:
                self.unreadable.append('%s: %s' % (d.name, type(e).__name__))
                continue
            self.domains[d.name] = {'name': name, 'file': f, 'range': rng, 'last': v, 'acc': 0}

    def reset(self):
        for x in self.domains.values():
            x['last'], x['acc'] = int(x['file'].read_text()), 0

    def poll(self):
        for x in self.domains.values():
            v = int(x['file'].read_text())
            d = v - x['last']
            if d < 0:
                d += x['range']
            x['acc'] += d
            x['last'] = v

    def joules(self):
        per = {k: {'name': x['name'], 'joules': x['acc'] / 1e6} for k, x in self.domains.items()}
        # Package total: top-level intel-rapl:N domains (the mmio package and the
        # :N:M subdomains are contained in, or duplicate, the package counter).
        pk = [v['joules'] for k, v in per.items() if k.count(':') == 1 and k.startswith('intel-rapl:')
              and v['name'].startswith('package')]
        return per, (sum(pk) if pk else None)


# ---------------------------------------------------------------- sampler
class Sampler(threading.Thread):
    def __init__(self, nvml, rapl, cgfile=None):
        super().__init__(daemon=True)
        self.nvml, self.rapl, self.cgfile = nvml, rapl, cgfile
        self.stop_ev = threading.Event()
        self.n = 0
        self.mem_peak = self.mem_min = None
        self.own_peak = 0
        self.util_max = self.util_sum = self.umem_max = 0
        self.util_nonzero = 0
        self.power_max = 0
        self.power_j = 0.0
        self.last_t = None
        self.sm_max = 0
        self.cg_current_peak = 0
        self.cg = None
        self.foreign = set()

    def pids(self):
        if self.cg is None and self.cgfile and os.path.exists(self.cgfile):
            self.cg = CGROOT / Path(open(self.cgfile).read().strip()).relative_to('/')
        if self.cg is None:
            return set()
        try:
            cur = int((self.cg / 'memory.current').read_text())
            self.cg_current_peak = max(self.cg_current_peak, cur)
            return {int(x) for x in (self.cg / 'cgroup.procs').read_text().split()}
        except (OSError, ValueError):
            return set()

    def run(self):
        while not self.stop_ev.is_set():
            pids = self.pids()
            if self.rapl.domains:
                try:
                    self.rapl.poll()
                except OSError:
                    pass
            if self.nvml.ok:
                s = self.nvml.sample(pids)
                self.n += 1
                mu = s.get('mem_used')
                if mu is not None:
                    self.mem_peak = mu if self.mem_peak is None else max(self.mem_peak, mu)
                    self.mem_min = mu if self.mem_min is None else min(self.mem_min, mu)
                self.own_peak = max(self.own_peak, s.get('own_mem', 0))
                self.foreign |= s.get('foreign', set())
                g = s.get('util_gpu', 0)
                self.util_max, self.util_sum = max(self.util_max, g), self.util_sum + g
                self.util_nonzero += g > 0
                self.umem_max = max(self.umem_max, s.get('util_mem', 0))
                self.power_max = max(self.power_max, s.get('power_mw', 0))
                now = time.monotonic()
                if 'power_mw' in s and self.last_t is not None:
                    self.power_j += s['power_mw'] / 1000 * (now - self.last_t)
                self.last_t = now
                self.sm_max = max(self.sm_max, s.get('sm_mhz', 0))
            self.stop_ev.wait(PERIOD)

    def stop(self):
        self.stop_ev.set()
        self.join()
        if self.rapl.domains:
            self.rapl.poll()


def window(nvml, rapl, seconds=None, action=None, cgfile=None):
    """Measure energy over a sleep of `seconds`, or over action()."""
    if rapl.domains:
        rapl.reset()
    s = Sampler(nvml, rapl, cgfile)
    e0 = nvml.energy_mj() if nvml.ok and nvml.has_energy else None
    t0 = time.monotonic()
    s.start()
    out = time.sleep(seconds) if action is None else action()
    s.stop()
    t1 = time.monotonic()
    e1 = nvml.energy_mj() if nvml.ok and nvml.has_energy else None
    per, cpu = rapl.joules() if rapl.domains else ({}, None)
    return out, {
        'seconds': t1 - t0,
        'gpu_joules': ((e1 - e0) / 1000 if e0 is not None and e1 is not None
                       else (s.power_j if nvml.ok and s.n else None)),
        'gpu_energy_source': ('nvml_total_energy_counter' if e0 is not None and e1 is not None
                              else ('nvml_power_samples_integrated' if nvml.ok and s.n else None)),
        'cpu_package_joules': cpu,
        'rapl_domains': per,
        'gpu_samples': s.n,
        'gpu_mem_used_peak_bytes': s.mem_peak,
        'gpu_mem_used_min_bytes': s.mem_min,
        'gpu_mem_own_processes_peak_bytes': s.own_peak,
        'gpu_util_max_pct': s.util_max,
        'gpu_util_mean_pct': s.util_sum / s.n if s.n else None,
        'gpu_util_nonzero_samples': s.util_nonzero,
        'gpu_mem_util_max_pct': s.umem_max,
        'gpu_power_max_watts': s.power_max / 1000,
        'gpu_sm_clock_max_mhz': s.sm_max,
        'cgroup_memory_current_peak_bytes': s.cg_current_peak or None,
        'gpu_foreign_compute_processes': sorted(
            '%d:%s' % (p, _comm(p)) for p in s.foreign),
    }


def _comm(pid):
    try:
        return open('/proc/%d/comm' % pid).read().strip()
    except OSError:
        return '?'


def sha256(path):
    try:
        with open(path, 'rb') as f:
            return hashlib.file_digest(f, 'sha256').hexdigest()
    except OSError:
        return None


def power_state():
    """AC/battery, CPU governor/profile and current MHz: a laptop on battery in
    power-saver runs at a fraction of its clock, which invalidates comparisons."""
    def rd(p):
        try:
            return Path(p).read_text().strip()
        except OSError:
            return None
    ps = Path('/sys/class/power_supply')
    ac = [rd(d / 'online') for d in ps.glob('*') if rd(d / 'type') == 'Mains']
    bat = {d.name: rd(d / 'status') for d in ps.glob('BAT*')}
    mhz = []
    try:
        mhz = [float(l.split(':')[1]) for l in open('/proc/cpuinfo') if l.startswith('cpu MHz')]
    except OSError:
        pass
    return {'ac_online': (ac[0] == '1') if ac else None, 'battery': bat,
            'governor': rd('/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor'),
            'platform_profile': rd('/sys/firmware/acpi/platform_profile'),
            'epp': rd('/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference'),
            'cpu_mhz_mean': sum(mhz) / len(mhz) if mhz else None,
            'cpu_max_khz': rd('/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq')}


def uptime():
    return subprocess.run(['uptime'], capture_output=True, text=True).stdout.strip()


def measure(cmd, cap='3G', baseline_seconds=5.0, outputs=(), label=None, lock=LOCK,
            timeout=0, stdout=None, cwd=None, env_extra=None):
    """Library entry point: returns the JSON-able record for one run."""
    nvml, rapl = NVML(), RAPL()
    rec = {'label': label, 'command': list(map(str, cmd)), 'cap': cap, 'host': socket.gethostname(),
           'started_at': time.strftime('%Y-%m-%dT%H:%M:%S%z')}
    lockf = open(lock, 'a') if lock else None
    try:
        if lockf:
            t = time.monotonic()
            fcntl.flock(lockf, fcntl.LOCK_EX)
            rec['lock_wait_seconds'] = time.monotonic() - t
        rec['uptime_before'] = uptime()
        rec['power_before'] = power_state()
        if nvml.ok:
            rec['power_before']['gpu'] = nvml.state()
        base = None
        if baseline_seconds and baseline_seconds > 0:
            _, base = window(nvml, rapl, seconds=baseline_seconds)
        with tempfile.TemporaryDirectory(prefix='ebench-') as tmp:
            res = os.path.join(tmp, 'inner.json')
            env = dict(os.environ, CAP=cap, BEND_NO_TELEMETRY='1')
            env.update(env_extra or {})
            full = ['sh', str(CAPPED_SH), sys.executable, '-I', os.path.abspath(__file__),
                    '--_inner', res, '--timeout', str(timeout), '--', *map(str, cmd)]
            def act():
                with open(stdout, 'wb') if stdout else open(os.devnull, 'wb') as so:
                    return subprocess.run(full, env=env, stdout=so, cwd=cwd).returncode
            outer_rc, run = window(nvml, rapl, action=act, cgfile=res + '.cg')
            try:
                inn = json.loads(Path(res).read_text())
            except (OSError, ValueError):
                inn = {'returncode': None, 'error': 'inner helper produced no result (killed: exit %s)' % outer_rc}
        rec['uptime_after'] = uptime()
        rec['power_after'] = power_state()
    finally:
        if lockf:
            lockf.close()
    rec['outer_returncode'] = outer_rc
    rec.update(inn)
    if inn.get('returncode') is None and outer_rc == 137:
        rec['error'] = 'killed (exit 137): exceeded memory cap %s' % cap
    rec['ok'] = inn.get('returncode') == 0 and not inn.get('timed_out')
    rec['outer_wall_seconds'] = run['seconds']
    rec['gpu'] = {'available': nvml.ok, 'error': nvml.error,
                  'name': getattr(nvml, 'name', None), 'driver': getattr(nvml, 'driver', None)}
    rec['rapl'] = {'available': bool(rapl.domains), 'domains': sorted(rapl.domains),
                   'unreadable': rapl.unreadable}
    rec['run'] = run
    rec['baseline'] = base
    # Net energy: raw minus baseline power over the run's (outer) window.
    def net(key):
        r = run.get(key)
        if r is None or base is None or base.get(key) is None or not base['seconds']:
            return None
        return r - base[key] / base['seconds'] * run['seconds']
    rec['energy'] = {
        'gpu_raw_joules': run['gpu_joules'], 'gpu_net_joules': net('gpu_joules'),
        'cpu_raw_joules': run['cpu_package_joules'], 'cpu_net_joules': net('cpu_package_joules'),
        'gpu_baseline_watts': base['gpu_joules'] / base['seconds'] if base and base['gpu_joules'] is not None else None,
        'cpu_baseline_watts': (base['cpu_package_joules'] / base['seconds']
                               if base and base['cpu_package_joules'] is not None else None),
        'cpu_note': None if rapl.domains else 'RAPL energy_uj not readable (root-only): CPU energy unavailable, not estimated',
    }
    if base and run.get('gpu_mem_used_peak_bytes') is not None and base.get('gpu_mem_used_peak_bytes') is not None:
        rec['gpu_mem_peak_above_baseline_bytes'] = run['gpu_mem_used_peak_bytes'] - base['gpu_mem_used_peak_bytes']
    rec['outputs'] = {str(o): sha256(o) for o in outputs}
    return rec


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv[:1] == ['--_inner']:
        ap = argparse.ArgumentParser()
        ap.add_argument('--_inner', dest='res')
        ap.add_argument('--timeout', type=float, default=0)
        ap.add_argument('cmd', nargs=argparse.REMAINDER)
        a = ap.parse_args(argv)
        cmd = a.cmd[1:] if a.cmd[:1] == ['--'] else a.cmd
        return inner(a.res, a.timeout, cmd)
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--cap', default=os.environ.get('CAP', '3G'), help='per-run memory cap (default $CAP or 3G)')
    ap.add_argument('--baseline-seconds', type=float, default=5.0,
                    help='idle baseline length right before the run (use the expected run length)')
    ap.add_argument('--output', action='append', default=[], help='file whose sha256 is recorded (repeatable)')
    ap.add_argument('--label')
    ap.add_argument('--lock', default=LOCK, help="bench lock file ('' = none)")
    ap.add_argument('--timeout', type=float, default=0, help='kill the command after N seconds (0 = none)')
    ap.add_argument('--stdout', help='redirect the command stdout to this file (default /dev/null)')
    ap.add_argument('--jsonl', help='append the JSON record to this file')
    ap.add_argument('cmd', nargs=argparse.REMAINDER)
    a = ap.parse_args(argv)
    cmd = a.cmd[1:] if a.cmd[:1] == ['--'] else a.cmd
    if not cmd:
        ap.error('no command')
    rec = measure(cmd, a.cap, a.baseline_seconds, a.output, a.label, a.lock or None, a.timeout, a.stdout)
    line = json.dumps(rec, sort_keys=True)
    print(line, flush=True)
    if a.jsonl:
        with open(a.jsonl, 'a') as f:
            f.write(line + '\n')
    return 0 if rec['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
