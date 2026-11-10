"""Actual-source/full-SDK macOS ownership regression; no Xcode build phases."""

import os
from pathlib import Path
import platform
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(os.environ.get("METAPHONE_SOURCE_ROOT", ROOT)).resolve()


@unittest.skipUnless(platform.system() == "Darwin", "requires macOS frameworks and clang++")
class OwnershipTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="metaphone-ownership-")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.binary = Path(cls.temp.name) / "ownership"
        subprocess.run([
            "clang++", "-std=c++11", "-x", "objective-c++", "-g", "-w",
            "-fsanitize=address,undefined", "-fno-omit-frame-pointer",
            "-I", str(SOURCE), "-I", str(SOURCE / "4D Plugin API"),
            str(ROOT / ".github/tests/ownership.mm"),
            str(SOURCE / "4D Plugin API/4DPluginAPI.c"),
            str(SOURCE / "4D Plugin API/Classes/ARRAY_TEXT.cpp"),
            str(SOURCE / "4D Plugin API/Classes/C_TEXT.cpp"),
            "-framework", "Cocoa", "-framework", "CoreGraphics",
            "-o", str(cls.binary),
        ], check=True)

    def test_ownership(self):
        for case in ("command", "outputs", "setters", "getter-string",
                     "getter-boolean", "getter-number", "getter-collection", "arrays", "text"):
            for empty in ("allocated", "null"):
                with self.subTest(case=case, empty=empty):
                    result = subprocess.run(
                        [str(self.binary), case, empty], text=True, capture_output=True,
                        env={**os.environ, "ASAN_OPTIONS": "detect_leaks=0",
                             "UBSAN_OPTIONS": "halt_on_error=1"},
                    )
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
