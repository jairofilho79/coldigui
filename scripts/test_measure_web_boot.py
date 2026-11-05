#!/usr/bin/env python3
"""Focused boot diagnostics tests; browser traffic stays on localhost."""
from contextlib import redirect_stderr, redirect_stdout
import io
import json
import os
import shutil
import socket
import time
import unittest
from unittest.mock import Mock

import measure_web_boot as boot
from web_frontend_server import serve_frontend


class GateTests(unittest.TestCase):
    def test_ci_uses_stable_browser_and_runs_runner_regressions(self):
        workflow = (boot.ROOT / ".github/workflows/web.yml").read_text(encoding="utf-8")
        self.assertIn("chrome-version: stable", workflow)
        self.assertIn("python3 -B -m unittest test_task_delivery test_measure_web_boot", workflow)
        self.assertNotIn("diagnose_web_boot_ci.py", workflow)

    def test_loader_limit_150_passes_but_151_fails(self):
        baseline = boot.load_baseline(boot.DEFAULT_BASELINE)
        self.assertEqual(
            baseline["metrics"]["loaderVisibleMs"]["value"]
            + baseline["metrics"]["loaderVisibleMs"]["maxRegression"],
            150,
        )
        metrics = {"loaderVisibleMs": 150, "firstFrameMs": 5000}
        self.assertEqual(boot.check_against_baseline(metrics, baseline), [])
        metrics["loaderVisibleMs"] = 151
        self.assertEqual(
            boot.check_against_baseline(metrics, baseline),
            ["loaderVisibleMs: 151ms > limite 150ms (baseline 50 + 100)"],
        )

    def test_diagnostics_do_not_change_median_or_gate(self):
        samples = [
            {"loaderVisibleMs": 149, "firstFrameMs": 4999,
             "diagnostics": {"fcpMs": 9999}},
            {"loaderVisibleMs": 151, "firstFrameMs": 5001,
             "diagnostics": {"fcpMs": 1}},
        ]
        with unittest.mock.patch.object(boot, "measure_once", side_effect=samples):
            metrics = boot.median_run("chrome", "http://127.0.0.1/", 2)
        self.assertEqual(metrics["loaderVisibleMs"], 150)
        self.assertEqual(metrics["firstFrameMs"], 5000)
        self.assertEqual(metrics["samples"], samples)
        self.assertEqual(
            boot.check_against_baseline(metrics, boot.load_baseline(boot.DEFAULT_BASELINE)),
            [],
        )


class DiagnosticFailureTests(unittest.TestCase):
    def test_javascript_exception_is_not_success_or_leaked(self):
        ws = Mock()
        ws.call.return_value = {
            "exceptionDetails": {"text": "sensitive fixture URL"},
            "result": {"value": {"navigation": {}}},
        }
        with self.assertRaises(boot.CdpError) as raised:
            boot.collect_boot_diagnostics(ws)
        self.assertNotIn("sensitive fixture", str(raised.exception))

    def test_missing_diagnostic_object_is_failure(self):
        for result in ({}, {"result": {"value": None}}, {"result": {"value": {}}}):
            with self.subTest(result=result):
                ws = Mock()
                ws.call.return_value = result
                with self.assertRaises(boot.CdpError):
                    boot.collect_boot_diagnostics(ws)

    def test_cdp_failure_propagates(self):
        ws = Mock()
        ws.call.side_effect = boot.CdpError("CDP unavailable")
        with self.assertRaisesRegex(boot.CdpError, "CDP unavailable"):
            boot.collect_boot_diagnostics(ws)

    def test_cli_diagnostic_failure_is_nonzero_without_success_json(self):
        args = Mock(web_dir=boot.ROOT, runs=1, output=None, check=False)
        stdout, stderr = io.StringIO(), io.StringIO()
        with unittest.mock.patch.object(boot, "parse_args", return_value=args), \
                unittest.mock.patch.object(boot, "find_chrome", return_value="chrome"), \
                unittest.mock.patch.object(
                    boot, "median_run", side_effect=boot.CdpError("diagnóstico ausente")
                ), redirect_stdout(stdout), redirect_stderr(stderr):
            result = boot.main()
        self.assertEqual(result, 1)
        self.assertEqual(stdout.getvalue(), "")
        self.assertIn("diagnóstico ausente", stderr.getvalue())


class ChromeDiagnosticsTests(unittest.TestCase):
    def measure_fixture(self, html):
        try:
            chrome = boot.find_chrome()
        except boot.CdpError as err:
            self.skipTest(str(err))
        fixture = boot.ROOT / "build" / f"web-boot-fixture-{os.getpid()}-{time.time_ns()}"
        fixture.mkdir(parents=True)
        self.addCleanup(shutil.rmtree, fixture)
        (fixture / "index.html").write_text(html, encoding="utf-8")
        profiles_before = set((boot.ROOT / "build").glob(f"plpcg-measure-{os.getpid()}-*"))
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            cdp_port = sock.getsockname()[1]
        try:
            with serve_frontend(web_dir=fixture) as (_, port):
                return boot.measure_once(chrome, f"http://127.0.0.1:{port}/", cdp_port)
        finally:
            self.assertEqual(
                set((boot.ROOT / "build").glob(f"plpcg-measure-{os.getpid()}-*")),
                profiles_before,
            )

    def test_actual_navigation_paint_initial_longtask_and_bounded_output(self):
        perf = self.measure_fixture(
            """<!doctype html><html><body><h1>Local boot fixture</h1><script>
const installedBeforeApp = !!window.__plpcgBootDiagnostics;
setTimeout(() => {
  const initialStart = performance.now();
  while (performance.now() - initialStart < 150) {}
}, 50);
setTimeout(() => {
  const state = window.__plpcgBootDiagnostics;
  const initialTasks = state ? state.entries.slice() : [];
  if (state) state.record(Array.from({length: 25}, (_, i) => ({
    startTime: 1000 + i, duration: 51,
    name: 'https://fixture.invalid/private?token=not-a-secret',
    attribution: [{containerSrc: 'https://fixture.invalid/private'}],
  })));
  const nav = performance.getEntriesByType('navigation')[0];
  const fcp = performance.getEntriesByName('first-contentful-paint')[0];
  window.__plpcgPerf = {
    loaderVisibleMs: 150, firstFrameMs: Math.round(performance.now()),
    rendererPreload: 'fixture',
    fixtureExpected: {
      installedBeforeApp, initialTasks,
      navigation: {
        responseEnd: nav.responseEnd, domInteractive: nav.domInteractive,
        domContentLoadedEventEnd: nav.domContentLoadedEventEnd,
      },
      fcpMs: fcp ? fcp.startTime : null,
      visibilityState: document.visibilityState, hasFocus: document.hasFocus(),
    },
  };
}, 400);
</script></body></html>""",
        )
        self.assertIn("diagnostics", perf)
        expected = perf["fixtureExpected"]
        diagnostics = perf["diagnostics"]
        self.assertTrue(expected["installedBeforeApp"])
        self.assertTrue(
            any(t["duration"] >= 60 for t in expected["initialTasks"]),
            expected["initialTasks"],
        )
        self.assertEqual(diagnostics["navigation"], expected["navigation"])
        self.assertGreater(diagnostics["navigation"]["responseEnd"], 0)
        self.assertGreaterEqual(
            diagnostics["navigation"]["domInteractive"],
            diagnostics["navigation"]["responseEnd"],
        )
        self.assertGreaterEqual(
            diagnostics["navigation"]["domContentLoadedEventEnd"],
            diagnostics["navigation"]["domInteractive"],
        )
        self.assertEqual(diagnostics["fcpMs"], expected["fcpMs"])
        self.assertGreater(diagnostics["fcpMs"], 0)
        self.assertEqual(diagnostics["loaderMinusFcpMs"], 150 - expected["fcpMs"])
        self.assertEqual(diagnostics["visibilityState"], expected["visibilityState"])
        self.assertEqual(diagnostics["hasFocus"], expected["hasFocus"])
        self.assertEqual(len(diagnostics["longTasks"]), 20)
        self.assertGreaterEqual(diagnostics["longTaskCount"], 25)
        self.assertTrue(diagnostics["longTasksTruncated"])
        for entry in diagnostics["longTasks"]:
            self.assertEqual(set(entry), {"startTime", "duration"})
        self.assertLess(len(json.dumps(diagnostics)), 4096)
        self.assertNotIn("fixture.invalid", json.dumps(diagnostics))
        self.assertEqual(perf["loaderVisibleMs"], 150)
        self.assertEqual(perf["rendererPreload"], "fixture")

    def test_actual_missing_fcp_is_failure_and_profile_is_cleaned(self):
        with self.assertRaisesRegex(boot.CdpError, "diagnóstico de boot"):
            self.measure_fixture("""<!doctype html><h1>Local failure fixture</h1>
<script>setTimeout(() => {
  performance.getEntriesByName = () => [];
  window.__plpcgPerf = {loaderVisibleMs: 150, firstFrameMs: 300};
}, 300);</script>""")

    def test_actual_unsupported_observer_is_failure_and_profile_is_cleaned(self):
        source = "{const PerformanceObserver = {supportedEntryTypes: []};\n" \
            + boot.BOOT_DIAGNOSTICS_INIT_JS + "\n}"
        with unittest.mock.patch.object(boot, "BOOT_DIAGNOSTICS_INIT_JS", source), \
                self.assertRaisesRegex(boot.CdpError, "diagnóstico de boot"):
            self.measure_fixture("""<!doctype html><h1>Local failure fixture</h1>
<script>setTimeout(() => {
  window.__plpcgPerf = {loaderVisibleMs: 150, firstFrameMs: 300};
}, 300);</script>""")


if __name__ == "__main__":
    unittest.main()
