import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("notary", Path(__file__).parents[1] / "validate-developer-id-release.py")
notary = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notary)

class NotaryTests(unittest.TestCase):
    def test_accepted_empty_and_null_issues(self):
        for issues in ([], None):
            self.assertEqual(notary.inspect_notary_result({"status": "Accepted", "id": "test"}, {"issues": issues}), ("test", 0, 0))
    def test_rejected_or_pending_must_not_publish(self):
        for status in ("Invalid", "In Progress", None):
            with self.assertRaises(ValueError):
                notary.inspect_notary_result({"status": status, "id": "test"}, {"issues": []})
    def test_errors_and_warnings_block_publication(self):
        for severity in ("error", "warning"):
            with self.assertRaises(ValueError):
                notary.inspect_notary_result({"status": "Accepted", "id": "test"}, {"issues": [{"severity": severity}]})
    def test_missing_submission_id_is_not_success(self):
        with self.assertRaises(ValueError):
            notary.inspect_notary_result({"status": "Accepted"}, {"issues": []})
