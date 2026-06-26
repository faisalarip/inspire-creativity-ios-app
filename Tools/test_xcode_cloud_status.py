#!/usr/bin/env python3
"""Unit tests for the pure logic in xcode_cloud_status.py.

Covers response parsing, latest-run selection, workflow filtering, terminal
detection, and exit-code mapping — everything except the network/JWT layer
(which is validated against the first real Xcode Cloud run, per spec §9).

Run:  python3 Tools/test_xcode_cloud_status.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import xcode_cloud_status as x  # noqa: E402


def run(number, progress, status=None, wf_id=None, **extra):
    attrs = {"number": number, "executionProgress": progress, "completionStatus": status}
    attrs.update(extra)
    res = {"id": f"run-{number}", "type": "ciBuildRuns", "attributes": attrs}
    if wf_id is not None:
        res["relationships"] = {"workflow": {"data": {"id": wf_id, "type": "ciWorkflows"}}}
    return res


class SummarizeRun(unittest.TestCase):
    def test_flattens_attributes(self):
        s = x.summarize_run(run(42, "COMPLETE", "SUCCEEDED", finishedDate="2026-06-22T10:00:00Z"))
        self.assertEqual(s["id"], "run-42")
        self.assertEqual(s["number"], 42)
        self.assertEqual(s["progress"], "COMPLETE")
        self.assertEqual(s["status"], "SUCCEEDED")
        self.assertEqual(s["finished"], "2026-06-22T10:00:00Z")

    def test_tolerates_missing_attributes(self):
        s = x.summarize_run({"id": "bare"})
        self.assertEqual(s["id"], "bare")
        self.assertIsNone(s["number"])
        self.assertIsNone(s["progress"])


class PickLatest(unittest.TestCase):
    def test_picks_highest_number(self):
        runs = [run(7, "COMPLETE", "SUCCEEDED"), run(12, "RUNNING"), run(9, "COMPLETE", "FAILED")]
        self.assertEqual(x.pick_latest(runs)["id"], "run-12")

    def test_empty_is_none(self):
        self.assertIsNone(x.pick_latest([]))

    def test_falls_back_when_numbers_missing(self):
        runs = [{"id": "a", "attributes": {}}]
        self.assertEqual(x.pick_latest(runs)["id"], "a")


class WorkflowFilter(unittest.TestCase):
    included = [
        {"type": "ciWorkflows", "id": "wf-rel", "attributes": {"name": "Release"}},
        {"type": "ciWorkflows", "id": "wf-pr", "attributes": {"name": "PR Check"}},
    ]

    def test_maps_names(self):
        m = x.workflow_names_by_id(self.included)
        self.assertEqual(m, {"wf-rel": "Release", "wf-pr": "PR Check"})

    def test_filters_case_insensitively(self):
        runs = [run(1, "COMPLETE", "SUCCEEDED", wf_id="wf-rel"),
                run(2, "COMPLETE", "FAILED", wf_id="wf-pr")]
        kept = x.filter_by_workflow(runs, self.included, "release")
        self.assertEqual([r["id"] for r in kept], ["run-1"])

    def test_no_match_returns_empty(self):
        runs = [run(1, "COMPLETE", "SUCCEEDED", wf_id="wf-pr")]
        self.assertEqual(x.filter_by_workflow(runs, self.included, "Release"), [])


class TerminalAndExitCodes(unittest.TestCase):
    def test_terminal_only_when_complete(self):
        self.assertTrue(x.is_terminal(x.summarize_run(run(1, "COMPLETE", "SUCCEEDED"))))
        self.assertFalse(x.is_terminal(x.summarize_run(run(1, "RUNNING"))))
        self.assertFalse(x.is_terminal(x.summarize_run(run(1, "PENDING"))))

    def test_exit_codes(self):
        self.assertEqual(x.exit_code_for(x.summarize_run(run(1, "COMPLETE", "SUCCEEDED"))), x.EXIT_OK)
        self.assertEqual(x.exit_code_for(x.summarize_run(run(1, "COMPLETE", "FAILED"))), x.EXIT_FAIL)
        self.assertEqual(x.exit_code_for(x.summarize_run(run(1, "COMPLETE", "ERRORED"))), x.EXIT_FAIL)
        self.assertEqual(x.exit_code_for(x.summarize_run(run(1, "COMPLETE", "CANCELED"))), x.EXIT_FAIL)
        self.assertEqual(x.exit_code_for(x.summarize_run(run(1, "COMPLETE", "SKIPPED"))), x.EXIT_FAIL)
        self.assertEqual(x.exit_code_for(x.summarize_run(run(1, "COMPLETE", None))), x.EXIT_FAIL)
        self.assertEqual(x.exit_code_for(x.summarize_run(run(1, "RUNNING"))), x.EXIT_PENDING)


class FormatSummary(unittest.TestCase):
    def test_success_line(self):
        line = x.format_summary(x.summarize_run(run(42, "COMPLETE", "SUCCEEDED")), "InspireCreativityApp")
        self.assertIn("build #42", line)
        self.assertIn("SUCCEEDED", line)

    def test_in_progress_line(self):
        line = x.format_summary(x.summarize_run(run(42, "RUNNING")), "InspireCreativityApp")
        self.assertIn("not finished", line)
        self.assertIn("RUNNING", line)

    def test_failure_line(self):
        line = x.format_summary(x.summarize_run(run(7, "COMPLETE", "FAILED")), "InspireCreativityApp")
        self.assertIn("build #7", line)
        self.assertIn("FAILED", line)
        self.assertIn("❌", line)

    def test_no_number_line(self):
        line = x.format_summary(
            x.summarize_run({"attributes": {"executionProgress": "COMPLETE", "completionStatus": "SUCCEEDED"}}),
            "InspireCreativityApp")
        self.assertNotIn("#", line)
        self.assertIn("SUCCEEDED", line)


class WorkflowId(unittest.TestCase):
    def test_extracts_id(self):
        self.assertEqual(x.run_workflow_id(run(1, "COMPLETE", "SUCCEEDED", wf_id="wf-rel")), "wf-rel")

    def test_none_when_absent(self):
        self.assertIsNone(x.run_workflow_id(run(1, "COMPLETE", "SUCCEEDED")))


class EndToEndParsing(unittest.TestCase):
    """A realistic /v1/ciProducts/{id}/buildRuns payload -> latest Release run."""

    payload = {
        "data": [
            run(31, "COMPLETE", "FAILED", wf_id="wf-rel"),
            run(33, "RUNNING", wf_id="wf-pr"),
            run(32, "COMPLETE", "SUCCEEDED", wf_id="wf-rel", finishedDate="2026-06-22T09:00:00Z"),
        ],
        "included": [
            {"type": "ciWorkflows", "id": "wf-rel", "attributes": {"name": "Release"}},
            {"type": "ciWorkflows", "id": "wf-pr", "attributes": {"name": "PR Check"}},
        ],
    }

    def test_latest_release_run_is_selected(self):
        release_runs = x.filter_by_workflow(self.payload["data"], self.payload["included"], "Release")
        latest = x.pick_latest(release_runs)
        summary = x.summarize_run(latest)
        self.assertEqual(summary["number"], 32)
        self.assertEqual(x.exit_code_for(summary), x.EXIT_OK)


if __name__ == "__main__":
    unittest.main(verbosity=2)
