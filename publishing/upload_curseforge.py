"""Upload the exact package.py runtime archive. Token comes only from environment."""
from pathlib import Path
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import package as build


def prepare(root=ROOT, release_type="beta", tag=""):
    if release_type not in {"alpha", "beta", "release"}:
        raise ValueError("Choose alpha, beta or release.")
    version, _ = build.read_manifest(root / "KeybindOptimizer")
    if tag and not re.fullmatch(r"v?" + re.escape(version) + r"(?:-(?:alpha|beta|rc)[.\d-]*)?", tag):
        raise ValueError("Release tag must match the addon TOC version.")
    config = json.loads((root / "publishing/curseforge.json").read_text(encoding="utf-8"))
    project = config["projectId"]
    if type(project) is not int or project <= 0:
        raise ValueError("CurseForge projectId must be a positive integer.")
    versions = config["gameVersionNames"]
    if not isinstance(versions, list) or not versions or any(not isinstance(v, str) or not re.fullmatch(r"\d+\.\d+\.\d+", v) for v in versions):
        raise ValueError("Configure explicit verified game version names.")
    archive = root / "dist" / f"HotSwap-{version}-CurseForge.zip"
    build.validate_runtime_archive(archive)
    checksum = archive.with_suffix(".sha256").read_text(encoding="ascii").split()
    if len(checksum) != 2 or checksum[1] != archive.name or checksum[0].lower() != hashlib.sha256(archive.read_bytes()).hexdigest():
        raise ValueError("Runtime archive does not match its SHA-256 manifest.")
    notes = root / "publishing" / f"changelog-{version}.txt"
    metadata = {"changelog": notes.read_text(encoding="utf-8"), "changelogType": "text",
                "displayName": f"Hot Swap {version}", "gameVersionNames": versions,
                "releaseType": release_type}
    return project, archive, metadata


def multipart(archive, metadata):
    boundary = "hotswap-" + uuid.uuid4().hex
    data = (f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n'
            'Content-Type: application/json\r\n\r\n').encode() + json.dumps(metadata).encode()
    data += (f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{archive.name}"\r\n'
             'Content-Type: application/zip\r\n\r\n').encode() + archive.read_bytes()
    data += f"\r\n--{boundary}--\r\n".encode()
    return boundary, data


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Never forward the publisher token to another host or repeat a POST.
        return None


def main():
    try:
        token = os.environ.get("CURSEFORGE_API_TOKEN", "").strip()
        if not token:
            raise ValueError("Add the CURSEFORGE_API_TOKEN repository Actions secret before publishing.")
        project, archive, metadata = prepare(release_type=os.environ.get("CF_RELEASE_TYPE", "beta"), tag=os.environ.get("CF_RELEASE_TAG", ""))
        boundary, body = multipart(archive, metadata)
        request = urllib.request.Request(f"https://wow.curseforge.com/api/projects/{project}/upload-file",
                                         data=body, method="POST", headers={"X-Api-Token": token,
                                         "Content-Type": f"multipart/form-data; boundary={boundary}"})
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=120) as response:
            result = json.load(response)
        file_id = result.get("id")
        if type(file_id) is not int or file_id <= 0:
            raise ValueError("Upload response did not identify a file. Check CurseForge before retrying.")
        message = f"Uploaded {archive.name} to CurseForge project {project}; file ID {file_id}. Moderation may still be pending."
        print(message)
        summary = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary:
            with open(summary, "a", encoding="utf-8") as stream:
                stream.write(message + "\n")
        return 0
    except urllib.error.HTTPError as exc:
        print(f"CurseForge returned HTTP {exc.code}. Check the token/project permissions and file list before retrying.", file=sys.stderr)
    except urllib.error.URLError:
        print("CurseForge upload connection failed. Check its file list before retrying; no automatic retry was made.", file=sys.stderr)
    except (OSError, ValueError, KeyError) as exc:
        print(str(exc), file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
