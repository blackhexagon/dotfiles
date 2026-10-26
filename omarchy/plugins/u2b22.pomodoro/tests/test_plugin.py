"""Offline regression tests: python3 -m unittest discover -s tests -v."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

PLUGIN = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location(
    "pomodoro_sync", PLUGIN / "pomodoro_sync.py"
)
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


class DescriptionTests(unittest.TestCase):
    def test_html_list_keeps_exercise_boundaries(self):
        self.assertEqual(
            sync.plain_description(
                "<p>Cviky</p><ul><li>Protáhni se<br>Pomalu</li><li>Voda &amp; okno</li></ul>"
            ),
            "Cviky\n\n• Protáhni se\nPomalu\n• Voda & okno",
        )

    def test_long_description_is_not_cut_mid_exercise(self):
        text = "1. " + ("Dýchej. " * 300).strip() + "\n2. Poslední cvik."
        self.assertEqual(sync.plain_description(text), text.strip())

    def test_description_survives_event_normalization(self):
        events = sync.timed_events(
            [
                {
                    "id": "exercise",
                    "description": "<p>1. Prkno</p><p>2. Voda</p>",
                    "start": {"dateTime": "2026-10-22T09:00:00+02:00"},
                    "end": {"dateTime": "2026-10-22T09:25:00+02:00"},
                }
            ]
        )
        self.assertEqual(events[0]["description"], "1. Prkno\n\n2. Voda")


@unittest.skipUnless(shutil.which("node"), "node is required for the pure JS tests")
class DayModelTests(unittest.TestCase):
    def test_exercise_sections(self):
        result = subprocess.run(
            [
                "node",
                "-e",
                r"""
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const day = vm.createContext({});
vm.runInContext(fs.readFileSync(process.argv[1], 'utf8').replace('.pragma library', ''), day);
const plain = value => JSON.parse(JSON.stringify(value));
assert.deepEqual(plain(day.descriptionSections('')), { intro: '', exercises: [] });
assert.deepEqual(plain(day.descriptionSections('Just prose\n\non two lines')), { intro: '', exercises: ['Just prose\n\non two lines'] });
assert.deepEqual(plain(day.descriptionSections('Cviky:\n1. Prkno\n  pokračování\n• vnořená odrážka\n2) Voda')), {
  intro: 'Cviky:', exercises: ['1. Prkno\n  pokračování\n• vnořená odrážka', '2) Voda'] });
assert.deepEqual(plain(day.descriptionSections('Cviky\r\n• Prkno\r\n• Voda')), { intro: 'Cviky', exercises: ['• Prkno', '• Voda'] });
assert.equal(day.descriptionSections('GoodDay #123\n\n1. ' + 'A'.repeat(5000) + '\n2. Voda').exercises.length, 2);
assert.equal(day.parseEvents([{id: 'a', description: '1. Prkno', startMs: 1, endMs: 2}])[0].description, '1. Prkno');
""",
                str(PLUGIN / "DayModel.js"),
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


@unittest.skipUnless(
    shutil.which("quickshell"), "quickshell is required for layout tests"
)
class LayoutTests(unittest.TestCase):
    def test_dial_and_phrase_input_stay_on_screen(self):
        commons = (
            Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy")) / "shell/Commons"
        )
        if not commons.is_dir():
            self.skipTest("Omarchy's Commons QML module is required")
        with tempfile.TemporaryDirectory(
            prefix="pomo-layout-", dir="/tmp/opencode"
        ) as directory:
            root = Path(directory)
            (root / "Commons").symlink_to(commons, target_is_directory=True)
            (root / "Ui").symlink_to(commons.parent / "Ui", target_is_directory=True)
            (root / "Plugin").symlink_to(PLUGIN, target_is_directory=True)
            (root / "shell.qml").write_text(
                (PLUGIN / "tests/layout_test.qml").read_text()
            )
            env = {
                **os.environ,
                "QT_QPA_PLATFORM": "offscreen",
                "QT_QUICK_BACKEND": "software",
            }
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(
                ["quickshell", "--no-color", "-p", directory],
                env=env,
                capture_output=True,
                text=True,
                timeout=30,
            )
            output = result.stdout + result.stderr
            verdicts = [
                line.split("LAYOUT_RESULT ", 1)[1]
                for line in output.splitlines()
                if "LAYOUT_RESULT " in line
            ]
            self.assertTrue(verdicts, output)
            verdict = json.loads(verdicts[-1])
            self.assertEqual(verdict["failures"], [], "\n".join(verdict["failures"]))
            self.assertNotIn("WARN scene", output, output)
            self.assertEqual(result.returncode, 0, output)


if __name__ == "__main__":
    unittest.main()
