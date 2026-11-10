"""Repository-specific preservation evidence, valid before and after a bump."""

import importlib.util
from pathlib import Path
import re
import stat
import subprocess
import sys
import unittest


ROOT = Path(__file__).resolve().parents[2]
BASE = "eed66fbec528e439b2b47c540456ddeb986d8e66"
sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location(
    "contract_source", ROOT / ".github/scripts/source_version.py"
)
source = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(source)


def original(path):
    return subprocess.check_output(["git", "-C", str(ROOT), "show", f"{BASE}:{path}"])


class RepositoryContractTests(unittest.TestCase):
    def test_existing_coordinated_header_overrides_fallback_body(self):
        bump = original(".github/workflows/bump-version.yml").decode()
        header, body = bump.split("name: Bump version", 1)
        self.assertIn("MARKETING_VERSION/CURRENT_PROJECT_VERSION AND Info.plist", header)
        self.assertIn("CFBundleShortVersionString/CFBundleVersion", header)
        self.assertIn('KEY="MARKETING_VERSION"', body)
        self.assertIn('KEY="CURRENT_PROJECT_VERSION"', body)
        release = original(".github/workflows/release.yml").decode()
        self.assertIn("  push:\n    tags:\n      - 'v*.*.*'", release)
        self.assertNotIn("pull_request:", release)
        self.assertNotIn("branches:", release)

    def test_source_has_only_authorized_version_token_changes(self):
        current = source.read(ROOT)
        for path in source.SOURCE_PATHS:
            with self.subTest(path=path):
                before = original(path)
                if path == source.LOCALIZED:
                    expected = before.replace(
                        b'CFBundleShortVersionString = "1.0.0";',
                        f'CFBundleShortVersionString = "{current}";'.encode(),
                    ).replace(
                        b"Metaphone version 1.0.0, Copyright 2022 miyako.",
                        f"Metaphone version {current}, Copyright 2022 miyako.".encode(),
                    )
                    self.assertNotIn(b"\n", before)
                    self.assertIn(b"\r", before)
                elif path == source.PROJECT:
                    expected = before.replace(
                        b"MARKETING_VERSION = 1.0.5;",
                        f"MARKETING_VERSION = {current};".encode(),
                    ).replace(
                        b"CURRENT_PROJECT_VERSION = 1.0.3;",
                        f"CURRENT_PROJECT_VERSION = {current};".encode(),
                    )
                else:
                    expected = before.replace(b"<string>1.0.5</string>",
                                              f"<string>{current}</string>".encode())
                self.assertEqual((ROOT / path).read_bytes(), expected)
                self.assertEqual(stat.S_IMODE((ROOT / path).stat().st_mode), 0o755)
        self.assertNotIn(b"<key>CFBundleVersion</key>", (ROOT / source.PLIST).read_bytes())

    def test_all_unrelated_original_files_preserved(self):
        paths = subprocess.check_output(
            ["git", "-C", str(ROOT), "ls-tree", "-r", "--name-only", BASE], text=True,
        ).splitlines()
        allowed = {*map(str, source.SOURCE_PATHS), "README.md",
                   "4DPlugin-Metaphone.cpp", "support/4DPlugin-JSON.cpp",
                   ".github/workflows/bump-version.yml", ".github/workflows/release.yml"}
        for name in paths:
            if name in allowed:
                continue
            with self.subTest(path=name):
                self.assertEqual((ROOT / name).read_bytes(), original(name))

    def test_unmodified_native_steps_and_secret_names(self):
        before = original(".github/workflows/release.yml").decode()
        after = (ROOT / ".github/workflows/release.yml").read_text()

        def block(workflow, name):
            return workflow.split(f"      - name: {name}\n", 1)[1].split(
                "\n      - name:", 1
            )[0].rstrip()

        for name in ("build x64", "import Developer ID certificate",
                     "store notarytool credentials", "codesign"):
            with self.subTest(step=name):
                self.assertEqual(block(before, name), block(after, name))
        secrets = r"\$\{\{ secrets\.([A-Z_]+) \}\}"
        self.assertEqual(re.findall(secrets, before), re.findall(secrets, after))
        for required in ('xcrun stapler staple "$DMG_PATH"',
                         'notarize "$ZIP_PATH"', 'notarize "$DMG_PATH"',
                         'if [ "$STATUS" != "Accepted" ]; then',
                         'ARCHS="arm64 x86_64"', "-configuration Default",
                         "CODE_SIGNING_ALLOWED=NO", "MACOS_DEPLOYMENT_TARGET: '11.0'",
                         "if-no-files-found: error"):
            self.assertIn(required, after)
        for required in ('xcrun stapler staple "$DMG_PATH"',
                         'ARCHS="arm64 x86_64"', "-configuration Default",
                         "CODE_SIGNING_ALLOWED=NO", "MACOS_DEPLOYMENT_TARGET: '11.0'",
                         "if-no-files-found: error"):
            self.assertIn(required, before)
            self.assertIn(required, after)
        for asset in ("ZIP_PATH", "DMG_PATH"):
            self.assertIn(f'xcrun notarytool submit "${asset}"', before)
            self.assertIn(f'notarize "${asset}"', after)

    def test_original_bump_history_and_later_explicit_coordinated_policy(self):
        created = subprocess.check_output(
            ["git", "-C", str(ROOT), "log", "--follow", "--format=%H", "--",
             ".github/workflows/bump-version.yml"], text=True,
        ).splitlines()[-1]
        self.assertEqual(created, "bbcbc4a18a131be0341770d4621118c20efbbf67")
        header = subprocess.check_output(
            ["git", "-C", str(ROOT), "show",
             f"{created}:.github/workflows/bump-version.yml"], text=True,
        ).split("name: Bump version", 1)[0]
        self.assertIn("MARKETING_VERSION/CURRENT_PROJECT_VERSION AND Info.plist", header)
        history = subprocess.check_output(
            ["git", "-C", str(ROOT), "show", "-s", "--format=%B",
             "4cd2f57322e36cf85201bfe677297db5bbf6fccf"], text=True,
        )
        self.assertIn("verifies MARKETING_VERSION, CURRENT_PROJECT_VERSION", history)


if __name__ == "__main__":
    unittest.main()
