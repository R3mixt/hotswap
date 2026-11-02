"""Regression checks for the installable CurseForge ZIP boundary."""
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package as build


class RuntimeArchiveTests(unittest.TestCase):
    def setUp(self):
        # Keep fixture writes inside the checkout, including in sandboxed runs.
        self.temporary = TemporaryDirectory(prefix=".hotswap-package-test-", dir=build.ROOT)
        self.addCleanup(self.temporary.cleanup)
        self.archive = Path(self.temporary.name) / "HotSwap-test-CurseForge.zip"
        self.toc_path = "KeybindOptimizer/KeybindOptimizer.toc"
        self.toc = "## Interface: 16001, 11509\n## Version: test\n\n" + "\n".join(build.MODULES) + "\n"
        self.files = {self.toc_path: self.toc}
        self.files.update({f"KeybindOptimizer/{module}": "-- fixture\n" for module in build.MODULES})

    def write(self, files=None):
        with zipfile.ZipFile(self.archive, "w", zipfile.ZIP_DEFLATED) as bundle:
            for name, content in (self.files if files is None else files).items():
                bundle.writestr(name, content)

    def test_valid_runtime_archive(self):
        self.write()
        self.assertEqual(build.validate_runtime_archive(self.archive), self.toc_path)

    def test_missing_toc_is_rejected(self):
        del self.files[self.toc_path]
        self.write()
        with self.assertRaisesRegex(ValueError, "immediate matching TOC"):
            build.validate_runtime_archive(self.archive)

    def test_source_wrapper_cannot_masquerade_as_runtime(self):
        self.write({f"HotSwap-test-source/{name}": content for name, content in self.files.items()})
        with self.assertRaisesRegex(ValueError, "only the KeybindOptimizer/ addon root"):
            build.validate_runtime_archive(self.archive)

    def test_missing_toc_load_file_is_rejected(self):
        del self.files["KeybindOptimizer/Core.lua"]
        self.write()
        with self.assertRaisesRegex(ValueError, "missing a TOC load file: Core.lua"):
            build.validate_runtime_archive(self.archive)

    def test_matching_toc_cannot_be_nested_under_addon_root(self):
        self.write({f"KeybindOptimizer/{name}": content for name, content in self.files.items()})
        with self.assertRaisesRegex(ValueError, "immediate matching TOC"):
            build.validate_runtime_archive(self.archive)

    def test_additional_root_is_rejected(self):
        self.files["OtherAddon/OtherAddon.toc"] = "## Interface: 11509\n"
        self.write()
        with self.assertRaisesRegex(ValueError, "only the KeybindOptimizer/ addon root"):
            build.validate_runtime_archive(self.archive)

    def test_traversing_toc_load_path_is_rejected(self):
        self.files[self.toc_path] += "../Core.lua\n"
        self.write()
        with self.assertRaisesRegex(ValueError, "Unsafe packaged TOC load path"):
            build.validate_runtime_archive(self.archive)


if __name__ == "__main__":
    unittest.main()
