"""Exercise the actual Bash hooks with isolated settings and JSON events."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class HookTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ste100-tests-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / "project"
        self.project.mkdir()
        self.config = self.root / "config"
        self.global_file = self.config / "ste100" / "level"
        self.legacy_file = self.root / "legacy" / "level"
        self.scripts = self.root / "plugin space" / "scripts"
        self.scripts.mkdir(parents=True)
        for source in (REPO / "scripts").glob("*.sh"):
            shutil.copy2(source, self.scripts / source.name)

        # Only redirect the legacy file binding in the temporary script copy.
        # This tests its fallback/migration without reading or removing a real
        # ~/.claude level file, and leaves HOME and CODEX_HOME unchanged.
        script = self.scripts / "ste-level.sh"
        source = script.read_text()
        binding = 'LEGACY_GLOBAL_FILE="${HOME}/.claude/ste100/level"'
        self.assertIn(binding, source)
        script.write_text(source.replace(binding, "LEGACY_GLOBAL_FILE=" + shlex.quote(str(self.legacy_file)), 1))

        self.env = dict(os.environ)
        for name in ("STE100_LEVEL", "STE100_PROJECT_DIR", "CLAUDE_PROJECT_DIR"):
            self.env.pop(name, None)
        self.env["XDG_CONFIG_HOME"] = str(self.config)

    def write_level(self, file, value):
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(value)

    def run_script(self, script, arguments=(), *, env=None, input_text=None):
        result = subprocess.run(
            ["/bin/bash", str(self.scripts / script), *arguments],
            input=input_text,
            text=True,
            capture_output=True,
            cwd=self.project,
            env=self.env if env is None else env,
            timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        return result.stdout

    def hook(self, prompt="Explain the result.", *, env=None, payload=None, wire=None):
        if wire is None:
            event = {
                "session_id": "test-session",
                "cwd": str(self.project),
                "hook_event_name": "UserPromptSubmit",
                "prompt": prompt,
            }
            if payload is not None:
                event.update(payload)
            wire = json.dumps(event)
        return self.run_script("ste-inject.sh", env=env, input_text=wire)

    def assert_mode(self, output, level):
        self.assertIn('<ste100 level="{}">'.format(level), output)
        self.assertIn("replaces all earlier STE100 hook instructions", output)

    def command(self, prompt):
        output = json.loads(self.hook(prompt))
        self.assertEqual(output["decision"], "block")
        return output["reason"]

    def test_default_and_off_explicitly_cancel_old_rules(self):
        self.assert_mode(self.hook(), 0)
        for value in ("0", "00", "off", "OFF", "Off"):
            with self.subTest(value=value):
                self.env["STE100_LEVEL"] = value
                output = self.hook()
                self.assert_mode(output, 0)
                self.assertIn("does not cancel an explicit request", output)
                self.assertNotIn("Do not use contractions", output)

    def test_rule_tiers_are_cumulative(self):
        previous = set()
        for level in range(10, 101, 10):
            with self.subTest(level=level):
                self.env["STE100_LEVEL"] = str(level)
                output = self.hook()
                self.assert_mode(output, level)
                writing_rules = output.split("Rules:\n", 1)[1].split("\nAccuracy has priority", 1)[0]
                current = set(line for line in writing_rules.splitlines() if line.startswith("- "))
                self.assertTrue(previous < current)
                previous = current
                self.assertEqual("Mark each place" in output, level >= 70)
                self.assertIn("Accuracy has priority over compliance", output)
                self.assertIn("Do not apply them to code", output)

    def test_numeric_rounding_and_no_overflow(self):
        cases = [(str(n), max(10, min(100, (n + 5) // 10 * 10))) for n in range(1, 101)]
        cases.extend([
            ("0", 0), ("0000", 0), ("0010", 10), ("099%", 100),
            ("101", 100), ("9223372036854775807", 100),
            ("18446744073709551616", 100), ("9" * 1000, 100),
        ])
        for value, expected in cases:
            with self.subTest(value=value):
                self.env["STE100_LEVEL"] = value
                self.assert_mode(self.hook(), expected)

    def test_command_prefixes_and_scopes(self):
        for prefix in ("ste", "/ste", "ste100:ste", "/ste100:ste", "STE", "/STE100:STE"):
            for suffix, expected in ((" 10", "10"), (" 75%", "80"), (" off", "0"), (" 0", "0")):
                with self.subTest(prefix=prefix, suffix=suffix):
                    self.command(prefix + suffix)
                    self.assertEqual(self.global_file.read_text().strip(), expected)
            self.command(prefix + " 40 --project")
            self.assertEqual((self.project / ".ste100-level").read_text().strip(), "40")
            self.assertIn("40%", self.command(prefix))
            self.assertIn("40%", self.command(prefix + " status --project"))
            self.command(prefix + " clear --project")
            self.assertFalse((self.project / ".ste100-level").exists())

    def test_decoded_whitespace_and_unicode_commands(self):
        for prompt in (" ste 70 ", "\nste 70\n", "\tste 70\t", "ste\t70", "ste\n70", "ste 70\t--project", "ste 70\r\n--project", "ste 70 --PROJECT"):
            with self.subTest(prompt=prompt):
                self.command(prompt)
                target = self.project / ".ste100-level" if "--" in prompt else self.global_file
                self.assertEqual(target.read_text().strip(), "70")
        result = self.hook(wire='{"prompt":"\\u0073te 70","cwd":' + json.dumps(str(self.project)) + "}")
        self.assertEqual(json.loads(result)["decision"], "block")

    def test_ordinary_messages_and_quoted_commands_are_not_intercepted(self):
        self.write_level(self.project / ".ste100-level", "40")
        for prompt in (
            "Please explain ste 70", 'Rewrite "ste 70"', "ste 70 and explain caching",
            "/ste-rewrite 70 text", "ste 70\nExplain caching", '{"prompt":"ste 70"}',
            '"cwd":"/tmp", "prompt":"ste off"', "Use /ste 70 in an example.",
        ):
            with self.subTest(prompt=prompt):
                self.assert_mode(self.hook(prompt), 40)
                self.assertEqual((self.project / ".ste100-level").read_text(), "40")
                self.assertFalse(self.global_file.exists())

    def test_escaped_project_paths_and_json_confirmations(self):
        for name in ("project space", "project-é", 'project"quote', "project\\backslash", "project\ttab", "project\rcarriage", "project\n", "project\bcontrol"):
            for host in ("codex", "claude"):
                with self.subTest(name=name, host=host):
                    self.project = self.root / name
                    self.project.mkdir(exist_ok=True)
                    if host == "claude":
                        self.env["CLAUDE_PROJECT_DIR"] = str(self.project)
                    else:
                        self.env.pop("CLAUDE_PROJECT_DIR", None)
                    self.assertIn(str(self.project), self.command("ste 70 --project"))
                    self.assertEqual((self.project / ".ste100-level").read_text().strip(), "70")
                    self.assert_mode(self.hook(), 70)
                    self.write_level(self.project / ".ste100-level", "high")
                    diagnostic = self.hook()
                    self.assert_mode(diagnostic, 0)
                    self.assertIn("ste off --project", diagnostic)
                    self.assertIn(str(self.project), self.command("ste status"))

    def test_settings_precedence(self):
        self.write_level(self.legacy_file, "10")
        self.assert_mode(self.hook(), 10)
        self.write_level(self.global_file, "20")
        self.assert_mode(self.hook(), 20)
        self.write_level(self.project / ".ste100-level", "40")
        self.assert_mode(self.hook(), 40)
        self.env["STE100_LEVEL"] = "70"
        self.assert_mode(self.hook(), 70)
        self.env["STE100_LEVEL"] = "off"
        self.assert_mode(self.hook(), 0)

    def test_off_and_lower_level_transitions_in_one_project(self):
        self.command("ste 70 --project")
        self.assert_mode(self.hook(), 70)
        self.command("ste 40 --project")
        lower = self.hook()
        self.assert_mode(lower, 40)
        self.assertNotIn("Do not use contractions", lower)
        self.command("ste off --project")
        self.assert_mode(self.hook(), 0)
        self.assertEqual((self.project / ".ste100-level").read_text().strip(), "0")

    def test_invalid_global_and_legacy_levels_are_repairable(self):
        for file in (self.global_file, self.legacy_file):
            for bad in ("high", "-10", "70.5", "abc", ""):
                with self.subTest(file=file, bad=bad):
                    self.global_file.unlink(missing_ok=True)
                    self.legacy_file.unlink(missing_ok=True)
                    self.write_level(file, bad)
                    output = self.hook()
                    self.assert_mode(output, 0)
                    self.assertIn("<ste100-error>", output)
                    self.assertIn("Send ste 70 or ste off", output)
                    self.command("ste 70")
                    self.assert_mode(self.hook(), 70)

    def test_invalid_project_recovery_uses_project_scope(self):
        self.write_level(self.global_file, "40")
        self.write_level(self.project / ".ste100-level", "high")
        output = self.hook()
        self.assert_mode(output, 0)
        self.assertIn("ste 70 --project", output)
        self.assertIn("ste off --project", output)
        self.assertIn("ste clear --project", output)
        self.command("ste 70 --project")
        self.assert_mode(self.hook(), 70)
        self.write_level(self.project / ".ste100-level", "high")
        self.command("ste clear --project")
        self.assert_mode(self.hook(), 40)

    def test_invalid_environment_recovery_uses_environment(self):
        self.env["STE100_LEVEL"] = "high"
        output = self.hook()
        self.assert_mode(output, 0)
        self.assertIn("Change or unset STE100_LEVEL", output)
        self.assertIn("start a new session", output)
        self.assertNotIn("Send ste 70", output)
        self.assertIn("another setting overrides", self.command("ste 70"))
        self.assert_mode(self.hook(), 0)
        self.env.pop("STE100_LEVEL")
        self.assert_mode(self.hook(), 70)

    def test_global_changes_warn_about_project_override(self):
        self.write_level(self.project / ".ste100-level", "70")
        reason = self.command("ste off")
        self.assertIn("another setting overrides", reason)
        self.assertIn("70%", reason)
        self.assertEqual(self.global_file.read_text().strip(), "0")
        self.assert_mode(self.hook(), 70)

    def test_legacy_migration_and_clear(self):
        self.write_level(self.legacy_file, "50")
        self.assert_mode(self.hook(), 50)
        self.command("ste 70")
        self.assertFalse(self.legacy_file.exists())
        self.assertEqual(self.global_file.read_text().strip(), "70")
        self.write_level(self.legacy_file, "50")
        self.command("ste clear")
        self.assertFalse(self.global_file.exists())
        self.assertFalse(self.legacy_file.exists())
        self.assert_mode(self.hook(), 0)

    def test_malformed_events_disable_old_mode_without_crashing(self):
        self.write_level(self.project / ".ste100-level", "70")
        for wire in ("", "{", "null", "[]", "{}", '{"prompt":null}', '{"prompt":[]}', '{"prompt":"ste 70","cwd":[]}', '{"prompt":"ste 70","cwd":"bad\\u0000path"}', '{"prompt":"ste 70"}\n{"prompt":"ste off"}'):
            with self.subTest(wire=wire):
                output = self.hook(wire=wire)
                self.assert_mode(output, 0)
                self.assertIn("could not read its JSON input", output)
                self.assertFalse(self.global_file.exists())

    def test_missing_jq_reports_dependency_and_cancels_old_mode(self):
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        for command in ("bash", "cat", "dirname"):
            (bin_dir / command).symlink_to(shutil.which(command))
        env = dict(self.env, PATH=str(bin_dir))
        output = self.hook(env=env)
        self.assert_mode(output, 0)
        self.assertIn("hook needs jq", output)
        self.assertIn("install jq", output)


if __name__ == "__main__":
    unittest.main()
