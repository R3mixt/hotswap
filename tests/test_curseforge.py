"""Publishing contract checks; no real token or network is used."""
from pathlib import Path
import hashlib
import importlib.util
import json
import shutil
import sys
from tempfile import TemporaryDirectory
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("publisher", ROOT / "publishing/upload_curseforge.py")
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)


class PublisherTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory(prefix=".hotswap-publisher-test-", dir=ROOT)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / "KeybindOptimizer", self.root / "KeybindOptimizer")
        (self.root / "publishing").mkdir()
        shutil.copy2(ROOT / "publishing/curseforge.json", self.root / "publishing/curseforge.json")
        self.version, modules = publisher.build.read_manifest(self.root / "KeybindOptimizer")
        (self.root / "publishing" / f"changelog-{self.version}.txt").write_text("Release notes", encoding="utf-8")
        (self.root / "dist").mkdir()
        self.archive = self.root / "dist" / f"HotSwap-{self.version}-CurseForge.zip"
        with zipfile.ZipFile(self.archive, "w") as bundle:
            for name in publisher.build.RUNTIME_FILES:
                bundle.write(self.root / "KeybindOptimizer" / name, "KeybindOptimizer/" + name)
        self.checksum()

    def checksum(self):
        digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        self.archive.with_suffix(".sha256").write_text(f"{digest}  {self.archive.name}\n", encoding="ascii")

    def test_exact_runtime_archive_and_metadata(self):
        project, archive, metadata = publisher.prepare(self.root, "beta", "v" + self.version)
        self.assertEqual(project, 1779519)
        self.assertEqual(archive, self.archive)
        self.assertEqual(metadata["gameVersionNames"], ["1.15.9"])
        self.assertEqual(metadata["releaseType"], "beta")
        self.assertEqual(metadata["changelog"], "Release notes")

    def test_tag_must_match_addon_version(self):
        with self.assertRaisesRegex(ValueError, "tag must match"):
            publisher.prepare(self.root, "release", "v999.0.0")

    def test_prerelease_tag_and_channel(self):
        publisher.prepare(self.root, "beta", "v" + self.version + "-beta.1")
        with self.assertRaises(ValueError):
            publisher.prepare(self.root, "invalid", "")

    def test_tampered_archive_is_rejected(self):
        with zipfile.ZipFile(self.archive, "a") as bundle:
            bundle.writestr("KeybindOptimizer/extra.txt", "changed after build")
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            publisher.prepare(self.root)

    def test_source_archive_cannot_be_uploaded(self):
        with zipfile.ZipFile(self.archive, "w") as bundle:
            bundle.writestr("HotSwap-source/README.md", "wrong artifact")
        self.checksum()
        with self.assertRaises(ValueError):
            publisher.prepare(self.root)

    def test_project_and_versions_are_explicit(self):
        for value in [{"projectId": "../wrong", "gameVersionNames": ["1.15.9"]},
                      {"projectId": 1779519, "gameVersionNames": []}]:
            (self.root / "publishing/curseforge.json").write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaises(ValueError):
                publisher.prepare(self.root)

    def test_multipart_contains_exact_zip_and_metadata(self):
        _, archive, metadata = publisher.prepare(self.root)
        boundary, body = publisher.multipart(archive, metadata)
        self.assertIn(archive.read_bytes(), body)
        self.assertIn(json.dumps(metadata).encode(), body)
        self.assertTrue(body.endswith(f"--{boundary}--\r\n".encode()))
        self.assertNotIn(b"Api-Token", body)

    def test_redirect_does_not_forward_credentials(self):
        self.assertIsNone(publisher.NoRedirect().redirect_request(None, None, 302, "redirect", {}, "https://example.org"))


if __name__ == "__main__":
    unittest.main()
