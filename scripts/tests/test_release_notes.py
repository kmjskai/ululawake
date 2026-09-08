import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    "release_notes", Path(__file__).parents[1] / "extract-release-notes.py"
)
release_notes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release_notes)
extract = release_notes.extract_release_notes


class ReleaseNotesTests(unittest.TestCase):
    def test_only_exact_version_with_nested_sections(self):
        changelog = (
            "# Changelog\n\n## 2026.9.10\nNewer entry.\n\n"
            "## 2026.9.1\nCurrent entry.\n\n### Installation\nInstall the DMG.\n\n"
            "## 2026.8.1\nOlder entry.\n"
        )
        self.assertEqual(
            extract(changelog, "2026.9.1"),
            "Current entry.\n\n### Installation\nInstall the DMG.\n",
        )

    def test_missing_version_does_not_use_another_entry(self):
        with self.assertRaises(ValueError):
            extract("## 2026.9.10\nDifferent version.\n", "2026.9.1")

    def test_duplicate_version_fails(self):
        with self.assertRaises(ValueError):
            extract("## 2026.9.1\nFirst.\n## 2026.9.1\nSecond.\n", "2026.9.1")

    def test_empty_entry_fails(self):
        for suffix in ("", "## 2026.8.1\nOlder entry.\n"):
            with self.subTest(suffix=suffix), self.assertRaises(ValueError):
                extract("## 2026.9.1\n\n" + suffix, "2026.9.1")

    def test_invalid_version_or_unsupported_heading_fails(self):
        for version, heading in (("v2026.9.1", "2026.9.1"), ("2026.9.1", "[2026.9.1]")):
            with self.subTest(version=version, heading=heading), self.assertRaises(ValueError):
                extract(f"## {heading}\nNotes.\n", version)

    def test_fenced_headings_are_content(self):
        for fence in ("```", "~~~~"):
            with self.subTest(fence=fence):
                body = f"Example:\n{fence}text\n## 2026.9.1\n## 2026.8.1\n{fence}\n"
                changelog = f"## 2026.9.1\n{body}\n## 2026.8.1\nOlder entry.\n"
                self.assertEqual(extract(changelog, "2026.9.1"), body)

    def test_unclosed_fence_fails(self):
        with self.assertRaises(ValueError):
            extract("## 2026.9.1\n```\nExample\n## 2026.8.1\nOlder\n", "2026.9.1")

    def test_crlf_and_last_entry(self):
        self.assertEqual(extract("## 2026.9.1\r\n\r\nNotes.\r\n", "2026.9.1"), "Notes.\n")
