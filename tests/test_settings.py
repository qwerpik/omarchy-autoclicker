"""Settings validation, persistence and the shared description string."""
import importlib
import json
import os
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "share"))


class SettingsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        os.environ["XDG_CONFIG_HOME"] = self.tmp.name
        import settings
        self.settings = importlib.reload(settings)
        self.path = pathlib.Path(self.tmp.name, "autoclicker/settings.json")

    def tearDown(self):
        self.tmp.cleanup()

    def test_defaults_when_missing(self):
        self.assertEqual(self.settings.load(), {"interval_ms": 5, "button": "left"})

    def test_round_trip(self):
        self.settings.save({"interval_ms": 20, "button": "right"})
        self.assertEqual(self.settings.load(), {"interval_ms": 20, "button": "right"})
        self.assertTrue(self.path.read_text().endswith("\n"))

    def test_partial_file_uses_defaults(self):
        self.path.parent.mkdir(parents=True)
        self.path.write_text(json.dumps({"button": "middle"}))
        self.assertEqual(self.settings.load(), {"interval_ms": 5, "button": "middle"})

    def test_rejects_bad_values(self):
        for bad in ({"interval_ms": 0, "button": "left"},
                    {"interval_ms": 60001, "button": "left"},
                    {"interval_ms": 5.0, "button": "left"},
                    {"interval_ms": True, "button": "left"},
                    {"interval_ms": 5, "button": "back"}):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                self.settings.validate(bad)

    def test_rejects_non_object_file(self):
        self.path.parent.mkdir(parents=True)
        self.path.write_text("[]")
        with self.assertRaises(ValueError):
            self.settings.load()

    def test_save_leaves_no_temp_files(self):
        self.settings.save({"interval_ms": 7, "button": "left"})
        self.assertEqual([p.name for p in self.path.parent.iterdir()], ["settings.json"])

    def test_invalid_save_keeps_old_file(self):
        self.settings.save({"interval_ms": 7, "button": "left"})
        with self.assertRaises(ValueError):
            self.settings.save({"interval_ms": -1, "button": "left"})
        self.assertEqual(self.settings.load()["interval_ms"], 7)

    def test_description(self):
        self.assertEqual(self.settings.description({"interval_ms": 5, "button": "left"}),
                         "Left click · 5 ms (200/s)")
        self.assertEqual(self.settings.description({"interval_ms": 3, "button": "middle"}),
                         "Middle click · 3 ms (333.333/s)")


if __name__ == "__main__":
    unittest.main()
