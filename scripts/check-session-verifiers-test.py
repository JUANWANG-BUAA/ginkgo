#!/usr/bin/env python3
"""Negative controls for historical and pinned-reference session verdicts."""
import importlib.util
from pathlib import Path
import unittest


def load(name):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


history = load("check-history-session-probes")
reference = load("check-ubaa-reference")
ui_history = load("check-beta-flutter-regressions")


def transcript(version):
    scenarios = ["ticket", "fallback", "uc_unavailable", "gateway_mismatch", "captcha_type"]
    if version in {"7", "working-tree"}:
        scenarios += ["cold_boot", "cold_boot_remembered"]
    if version == "working-tree":
        scenarios += ["checkin_direct_failure"]
    failures = history.EXPECTED_FAILURES[version]
    observations = "".join(f"OBS {name} result=synthetic\n" for name in scenarios)
    names = "".join(
        f"    services::tests::history_session_probe::history_session_observe_{name}\n"
        for name in sorted(failures)
    )
    summary = (f"test result: {'FAILED' if failures else 'ok'}. "
               f"{len(scenarios) - len(failures)} passed; {len(failures)} failed; 0 ignored;\n")
    return observations + names + summary


class SessionVerifierTest(unittest.TestCase):
    def test_ui_replay_never_accepts_loading_errors_or_skipped_tests(self):
        import json
        events = [
            {"type": "testStart", "test": {"id": 1, "name": "regression"}},
            {"type": "testDone", "testID": 1, "result": "failure", "skipped": False},
            {"type": "done", "success": False},
        ]
        output = lambda values: "\n".join(json.dumps(value) for value in values)
        self.assertEqual(ui_history.read_verdict(output(events), ["regression"]), ({"regression": "failure"}, False))
        for damaged in (
            events[1:],
            [events[0], {**events[1], "skipped": True}, events[2]],
            events + [events[2]],
            [events[0], events[0], events[1], events[2]],
        ):
            with self.subTest(damaged=damaged), self.assertRaises(ValueError):
                ui_history.read_verdict(output(damaged), ["regression"])
    def test_recorded_history_accepts_only_expected_exit_status(self):
        for version, failures in history.EXPECTED_FAILURES.items():
            code = 101 if failures else 0
            with self.subTest(version=version):
                history.validate_run(version, code, transcript(version))
                with self.assertRaises(ValueError):
                    history.validate_run(version, 0 if code else 101, transcript(version))
                with self.assertRaises(ValueError):
                    history.validate_run(version, -9, transcript(version))

    def test_missing_duplicate_or_renamed_observations_fail(self):
        original = transcript("working-tree")
        for damaged in (
            original.replace("OBS ticket result=synthetic\n", ""),
            original + "OBS ticket result=synthetic\n",
            original.replace("OBS ticket ", "OBS unrelated "),
        ):
            with self.subTest(damaged=damaged), self.assertRaises(ValueError):
                history.validate_run("working-tree", 0, damaged)

    def test_zero_skipped_missing_or_duplicate_results_fail(self):
        original = transcript("working-tree")
        for damaged in (
            original.replace("8 passed", "0 passed"),
            original.replace("0 ignored", "1 ignored"),
            original.split("test result:")[0],
            original + "test result: ok. 8 passed; 0 failed; 0 ignored;\n",
        ):
            with self.subTest(damaged=damaged), self.assertRaises(ValueError):
                history.validate_run("working-tree", 0, damaged)

    def test_unexpected_failure_cannot_replace_known_regression(self):
        damaged = transcript("4").replace("history_session_observe_fallback", "history_session_observe_ticket")
        with self.assertRaises(ValueError):
            history.validate_run("4", 101, damaged)

    def test_matching_current_stage_trace_is_required(self):
        oracle = {
            "ticket": ("SignedIn", ["CAS_GET:direct", "CAS_POST:direct", "CALLBACK:direct", "UC_ACTIVATE:direct", "UC_STATUS:direct"]),
            "uc_unavailable": ("Error", ["CAS_GET:direct", "CAS_POST:direct", "UC_ACTIVATE:direct", "UC_STATUS:direct"]),
        }
        current = {("working-tree", scenario): value for scenario, value in oracle.items()}
        reference.validate_current_stages(current, oracle)
        for changed in (
            {},
            {**current, ("working-tree", "ticket"): ("SignedIn", oracle["ticket"][1][:-1])},
            {**current, ("working-tree", "ticket"): ("SignedIn", list(reversed(oracle["ticket"][1])))},
            {**current, ("working-tree", "uc_unavailable"): ("SignedIn", oracle["uc_unavailable"][1])},
        ):
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                reference.validate_current_stages(changed, oracle)

    def test_capture_cannot_shrink_on_both_sides(self):
        expected = reference.BUSINESS_CASES
        full = [{"id": name} for name in expected]
        reference.validate_capture_ids({"cases": full}, "cases", expected)
        for damaged in ([], full[:-1], full + [full[0]], full[::-1]):
            with self.subTest(damaged=damaged), self.assertRaises(ValueError):
                reference.validate_capture_ids({"cases": damaged}, "cases", expected)

    def test_empty_transport_fixture_is_not_success(self):
        with self.assertRaises(ValueError):
            reference.validate_capture_ids({"requests": []}, "requests", [])


if __name__ == "__main__":
    unittest.main()
