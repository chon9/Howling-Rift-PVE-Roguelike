"""Rift3D regression runner (W0-A).

Usage:
  python -I tools/view3d/run_suite.py --mode 2d|3d [--only A,B*] [--network] [--visual]
         [--renderer gl_compatibility|forward_plus] [--jobs 3] [--timeout 180]
         [--write-baseline] [--kill-all-godot]

Headless logic tests run with the console exe and env HOWLING_VIEW=<mode>.
--network adds the multi-process LAN tests (ports 25100+); --visual adds the windowed visual scenes
(GUI exe, --windowed --resolution 1920x1080 --log-file). --only filters (fnmatch, comma separated)
inside the enabled categories.

Pass rule: exit code 0 and no line containing SCRIPT ERROR, Parse Error, SHADER ERROR or ERROR:,
except lines that contain an entry of tools/view3d/known_errors.txt (one substring per line, '#' comments).
Network tests additionally ignore NETWORK_SHUTDOWN_NOISE (the engine's ENet "max channels: 0" send error when the
host relays a peer removal to a guest that already quit); the ignored count is reported, exit codes still judge.

Writes .godot/view3d-suite-<mode>.json and prints "SUITE <mode>: passed X/Y; failed [...]".
Failures not listed in tools/view3d/baseline_2d.json are reported as NEW; the exit code is 1 only when
there are new failures. --write-baseline stores this run's failing set as baseline_2d.json.

Process hygiene: only processes started by this runner are killed (each child tree on timeout, every
remaining child at exit). --kill-all-godot additionally kills every Godot* process at exit (orchestrator
use only: other agents may be running Godot concurrently).
"""
import argparse
import concurrent.futures
import datetime
import fnmatch
import json
import os
import pathlib
import subprocess
import sys
import threading
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
CONSOLE_EXE = ROOT / "tools/steam/engine/Godot_v4.7.2-stable_win64_console.exe"
GUI_EXE_CANDIDATES = [pathlib.Path("K:/Godot_v4.7.2-stable_win64.exe"), ROOT / "tools/steam/engine/Godot_v4.7.2-stable_win64.exe"]
LOG_DIR = ROOT / ".godot/v3d-logs"
KNOWN_ERRORS = ROOT / "tools/view3d/known_errors.txt"
BASELINE = ROOT / "tools/view3d/baseline_2d.json"
BAD_PATTERNS = ("SCRIPT ERROR", "Parse Error", "SHADER ERROR", "ERROR:")
# Engine-side ENet error printed while peers shut down (no GDScript backtrace; seen in 2D and 3D, with every peer
# reporting 0 failures). Only network runs ignore it.
NETWORK_SHUTDOWN_NOISE = ("Unable to send packet on channel 0, max channels: 0",)

NETWORK = {
    "LanCoopTests": (["host", "client1", "client2"], []),
    "AssistBotsCoopTests": (["host", "client1", "client2"], []),
    "DeadeyeCoopTests": (["host", "client1", "client2"], []),
    "HookCoopTests": (["host", "client1", "client2"], []),
    "PassiveVisionCoopTests": (["host", "client1", "client2"], []),
    "Roster12CoopTests": (["host", "client1", "client2"], []),
    "SkillFootprintCoopTests": (["host", "client1", "client2"], []),
    "StatusCoopTests": (["host", "client1", "client2"], []),
    "SupportNetworkTests": (["host", "healer", "guardian"], []),
    "PvpNetworkTests": (["host", "guest"], ["1"]),
    "MatchLoadingNetworkTests": (["host", "fast", "slow"], ["pve"]),
    "BuildStealerNetworkTests": (["host", "guest1", "guest2"], []),
}
SKIPPED = {"SteamPeerTests"}
VISUAL_EXTRA = {"AnimationCombatPreview", "AnimationShowcase"}

_children = set()
_children_lock = threading.Lock()


def is_visual(name):
    return name.endswith("Visual") or name in VISUAL_EXTRA


def discover():
    names = sorted(p.stem for p in (ROOT / "tests").glob("*.tscn"))
    headless, network, visual, skipped = [], [], [], []
    for n in names:
        if n in SKIPPED:
            skipped.append(n)
        elif n in NETWORK:
            network.append(n)
        elif is_visual(n):
            visual.append(n)
        else:
            headless.append(n)
    return headless, network, visual, skipped


def load_known():
    if not KNOWN_ERRORS.exists():
        return []
    out = []
    for line in KNOWN_ERRORS.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            out.append(line)
    return out


def bad_lines(text, known):
    found = []
    for line in text.splitlines():
        if any(p in line for p in BAD_PATTERNS) and not any(k in line for k in known):
            found.append(line.strip())
    return found


def kill_tree(proc):
    if proc.poll() is None:
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            pass


def spawn(cmd, env, stdout):
    flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
    proc = subprocess.Popen(cmd, env=env, stdout=stdout, stderr=subprocess.STDOUT, creationflags=flags, cwd=str(ROOT))
    with _children_lock:
        _children.add(proc)
    return proc


def forget(proc):
    with _children_lock:
        _children.discard(proc)


def base_env(mode):
    env = dict(os.environ)
    env["HOWLING_VIEW"] = mode
    return env


def renderer_args(renderer):
    return ["--rendering-method", renderer] if renderer else []


def run_headless(name, args, known):
    log = LOG_DIR / ("suite-%s-%s.log" % (args.mode, name))
    cmd = [str(CONSOLE_EXE), "--headless", "--path", str(ROOT)] + renderer_args(args.renderer) + ["res://tests/%s.tscn" % name]
    start = time.time()
    timed_out = False
    with log.open("w", encoding="utf-8", errors="replace") as out:
        proc = spawn(cmd, base_env(args.mode), out)
        try:
            code = proc.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            kill_tree(proc)
            code = -1
        forget(proc)
    text = log.read_text(encoding="utf-8", errors="replace")
    return judge(name, "headless", [(name, code, timed_out, text, log)], known, time.time() - start)


def run_network(name, port, args, known):
    roles, extra = NETWORK[name]
    start = time.time()
    procs = []
    try:
        for role in roles:
            log = LOG_DIR / ("suite-%s-%s-%s.log" % (args.mode, name, role))
            out = log.open("w", encoding="utf-8", errors="replace")
            cmd = [str(CONSOLE_EXE), "--headless", "--path", str(ROOT)] + renderer_args(args.renderer)
            cmd += ["res://tests/%s.tscn" % name, "--", role] + extra + ["--no-steam", "--test-lan-port", str(port)]
            procs.append((role, spawn(cmd, base_env(args.mode), out), out, log))
            time.sleep(0.5 if role == "host" else 0.1)
        runs = []
        deadline = time.time() + args.timeout
        for role, proc, out, log in procs:
            timed_out = False
            try:
                code = proc.wait(timeout=max(1.0, deadline - time.time()))
            except subprocess.TimeoutExpired:
                timed_out = True
                kill_tree(proc)
                code = -1
            out.close()
            forget(proc)
            runs.append(("%s:%s" % (name, role), code, timed_out, log.read_text(encoding="utf-8", errors="replace"), log))
    finally:
        for role, proc, out, log in procs:
            kill_tree(proc)
            forget(proc)
            if not out.closed:
                out.close()
    return judge(name, "network", runs, known, time.time() - start)


def gui_exe():
    for c in GUI_EXE_CANDIDATES:
        if c.exists():
            return c
    return CONSOLE_EXE


def run_visual(name, args, known):
    log = LOG_DIR / ("suite-%s-%s.log" % (args.mode, name))
    if log.exists():
        log.unlink()
    cmd = [str(gui_exe()), "--path", str(ROOT), "--windowed", "--resolution", "1920x1080", "--log-file", str(log)]
    cmd += renderer_args(args.renderer) + ["res://tests/%s.tscn" % name]
    start = time.time()
    timed_out = False
    proc = spawn(cmd, base_env(args.mode), subprocess.DEVNULL)
    try:
        code = proc.wait(timeout=args.timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        kill_tree(proc)
        code = -1
    forget(proc)
    text = log.read_text(encoding="utf-8", errors="replace") if log.exists() else ""
    return judge(name, "visual", [(name, code, timed_out, text, log)], known, time.time() - start)


def judge(name, kind, runs, known, seconds):
    reasons, errors, logs, notes = [], [], [], []
    for label, code, timed_out, text, log in runs:
        logs.append(str(log))
        if timed_out:
            reasons.append("%s timeout" % label)
        elif code != 0:
            reasons.append("%s exit %s" % (label, code))
        bad = bad_lines(text, known)
        if kind == "network":
            noise = [b for b in bad if any(n in b for n in NETWORK_SHUTDOWN_NOISE)]
            if noise:
                bad = [b for b in bad if b not in noise]
                notes.append("%s ignored %d ENet shutdown line(s)" % (label, len(noise)))
        if bad:
            reasons.append("%s %d error line(s)" % (label, len(bad)))
            errors.extend("%s: %s" % (label, b) for b in bad[:8])
    ok = not reasons
    status = "PASS" if ok else "FAIL"
    detail = "; ".join(reasons + (["(%s)" % "; ".join(notes)] if notes else []))
    print("  %-34s %s %6.1fs %s" % (name, status, seconds, detail), flush=True)
    return {"name": name, "kind": kind, "ok": ok, "seconds": round(seconds, 1), "reasons": reasons, "errors": errors, "notes": notes, "logs": logs}


def select(names, only):
    if not only:
        return names
    pats = [p.strip() for p in only.split(",") if p.strip()]
    return [n for n in names if any(fnmatch.fnmatchcase(n, p) for p in pats)]


def kill_all_godot():
    subprocess.run(["powershell", "-NoProfile", "-Command",
                    "Get-Process | Where-Object { $_.ProcessName -like 'Godot*' } | Stop-Process -Force -ErrorAction SilentlyContinue"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    ap = argparse.ArgumentParser(description="Rift3D test suite runner")
    ap.add_argument("--mode", choices=["2d", "3d"], required=True)
    ap.add_argument("--only", default="")
    ap.add_argument("--network", action="store_true")
    ap.add_argument("--visual", action="store_true")
    ap.add_argument("--renderer", choices=["gl_compatibility", "forward_plus"], default="")
    ap.add_argument("--jobs", type=int, default=3)
    ap.add_argument("--timeout", type=int, default=180)
    ap.add_argument("--write-baseline", action="store_true", help="store this run's failing set in tools/view3d/baseline_2d.json")
    ap.add_argument("--kill-all-godot", action="store_true", help="also kill every Godot* process at exit (orchestrator only)")
    args = ap.parse_args()

    if not CONSOLE_EXE.exists():
        print("console exe missing: %s" % CONSOLE_EXE)
        return 2
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    known = load_known()
    headless, network, visual, skipped = discover()
    headless = select(headless, args.only)
    network = select(network, args.only) if args.network else []
    visual = select(visual, args.only) if args.visual else []
    started = datetime.datetime.now().isoformat(timespec="seconds")
    results = []
    print("SUITE %s: %d headless, %d network, %d visual (jobs %d, timeout %ds)" % (args.mode, len(headless), len(network), len(visual), args.jobs, args.timeout), flush=True)
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
            results += list(pool.map(lambda n: run_headless(n, args, known), headless))
        for i, n in enumerate(network):
            results.append(run_network(n, 25100 + i * 10, args, known))
        for n in visual:
            results.append(run_visual(n, args, known))
    finally:
        with _children_lock:
            leftovers = list(_children)
        for proc in leftovers:
            kill_tree(proc)
        if args.kill_all_godot:
            kill_all_godot()

    results.sort(key=lambda r: r["name"])
    passed = [r["name"] for r in results if r["ok"]]
    failed = [r["name"] for r in results if not r["ok"]]
    baseline_failed = []
    if BASELINE.exists():
        try:
            baseline_failed = json.loads(BASELINE.read_text(encoding="utf-8")).get("failed", [])
        except (ValueError, OSError):
            baseline_failed = []
    new_failures = [n for n in failed if n not in baseline_failed]
    report = {
        "mode": args.mode,
        "renderer": args.renderer or "project default",
        "started": started,
        "finished": datetime.datetime.now().isoformat(timespec="seconds"),
        "only": args.only,
        "passed": passed,
        "failed": failed,
        "new_failures_vs_baseline": new_failures,
        "skipped": skipped,
        "results": results,
    }
    out = ROOT / (".godot/view3d-suite-%s.json" % args.mode)
    out.write_text(json.dumps(report, indent=1), encoding="utf-8")
    if args.write_baseline:
        BASELINE.write_text(json.dumps({
            "generated": report["finished"],
            "mode": args.mode,
            "note": "Tests failing on the unmodified 2D game (W0-A). Later runs tolerate only these failures.",
            "total": len(results),
            "failed": failed,
            "reasons": {r["name"]: r["reasons"] for r in results if not r["ok"]},
        }, indent=1) + "\n", encoding="utf-8")
        print("baseline written: %s" % BASELINE)
    print("SUITE %s: passed %d/%d; failed %s" % (args.mode, len(passed), len(results), failed))
    if BASELINE.exists() and not args.write_baseline:
        print("NEW FAILURES vs baseline_2d.json: %s" % new_failures)
    return 1 if new_failures and not args.write_baseline else 0


if __name__ == "__main__":
    sys.exit(main())
