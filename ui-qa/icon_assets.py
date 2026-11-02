"""Fetch once, then verify a small preview-only cache of real game icons.

No WoW account or running client is used. Metadata comes from Wowhead's public
tooltips; artwork comes from its public ZAM CDN. This module is not addon code.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import argparse
import hashlib
import json
import re
import sys
from urllib.error import HTTPError
from urllib.request import Request, urlopen

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
MANIFEST = HERE / "icons" / "manifest.json"
CACHE = HERE / ".cache" / "icons"
ITEMS = (5512, 1710, 4388, 14530, 10577)
GENERIC = ("ability_mount_ridinghorse", "inv_jewelry_trinketpvp_01", "inv_misc_book_09", "spell_nature_wispsplode", "inv_misc_questionmark", "inv_misc_bag_08")


def fixtures():
    sys.path.insert(0, str(ROOT / "python-deps"))
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime()
    lua.execute((ROOT / "tests/mock.lua").read_text(encoding="utf-8"))
    namespace = lua.table()
    lua.compile((ROOT / "KeybindOptimizer/Profiles.lua").read_text(encoding="utf-8"))("KeybindOptimizer", namespace)
    spells = {int(s.id) for _, s in lua.globals().Mock.spells.items()}
    for _, entry in namespace.Profiles.Get(namespace.Profiles, "DRUID", "era").items():
        if entry.spellIDs[1]:
            spells.add(int(entry.spellIDs[1]))
    return [("spell", i) for i in sorted(spells)] + [("item", i) for i in ITEMS]


def read_url(url, limit):
    request = Request(url, headers={"User-Agent": "HotSwap-offline-preview/1.0"})
    with urlopen(request, timeout=25) as response:
        if response.url.split("/")[2] not in {"nether.wowhead.com", "wow.zamimg.com"}:
            raise ValueError("Unexpected asset redirect host")
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError("Preview asset exceeds size limit")
    return data


def metadata(pair):
    kind, identifier = pair
    # The fixture includes two non-Era spells. Only their artwork is used;
    # edition fallback is recorded and does not add them to the Era catalog.
    for edition in ("classic", "retail"):
        suffix = "classic/" if edition == "classic" else ""
        source = f"https://nether.wowhead.com/{suffix}tooltip/{kind}/{identifier}"
        try:
            value = json.loads(read_url(source, 300000))
        except HTTPError as error:
            if error.code == 404 and edition == "classic":
                continue
            raise
        icon = value.get("icon")
        if icon and re.fullmatch(r"[a-zA-Z0-9_]+", icon):
            return f"{kind}:{identifier}", {"id": identifier, "kind": kind, "name": value["name"], "icon": icon.lower(), "edition": edition, "metadataSource": source}
    raise ValueError(f"No verified icon metadata for {kind}:{identifier}")


def fetch():
    entries = fixtures()
    if len(entries) > 100:
        raise ValueError("Preview icon fixture unexpectedly exceeded 100 entities")
    existing = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {"entities": {}, "assets": {}}
    entities = {key: value for key, value in existing["entities"].items() if (value["kind"], value["id"]) in entries}
    missing = [pair for pair in entries if f"{pair[0]}:{pair[1]}" not in entities]
    with ThreadPoolExecutor(max_workers=4) as pool:
        for key, value in pool.map(metadata, missing):
            entities[key] = value
            print(f"Verified {key}: {value['icon']}", flush=True)
    names = sorted({value["icon"] for value in entities.values()} | set(GENERIC))
    CACHE.mkdir(parents=True, exist_ok=True)
    assets = {}
    for name in names:
        source = f"https://wow.zamimg.com/images/wow/icons/large/{name}.jpg"
        target = CACHE / f"{name}.jpg"
        expected = existing["assets"].get(name, {}).get("sha256")
        cached_valid = target.exists() and (not expected or hashlib.sha256(target.read_bytes()).hexdigest() == expected)
        if not cached_valid:
            data = read_url(source, 100000)
            if not data.startswith(b"\xff\xd8\xff"):
                raise ValueError(f"Not a JPEG icon: {source}")
            if expected and hashlib.sha256(data).hexdigest() != expected:
                raise ValueError(f"Published icon changed: review metadata before replacing pinned asset {name}")
            target.write_bytes(data)
        data = target.read_bytes()
        assets[name] = {"url": source, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}
    document = {"schema": 1, "attribution": "World of Warcraft icon artwork belongs to Blizzard Entertainment. Preview-only cache served by Wowhead/ZAM; not part of the MIT-licensed addon runtime.", "entities": dict(sorted(entities.items())), "assets": assets}
    MANIFEST.parent.mkdir(exist_ok=True)
    MANIFEST.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return verify()


def verify():
    if not MANIFEST.exists():
        raise ValueError("Icon metadata missing. Run python ui-qa/icon_assets.py --fetch once.")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for name, asset in manifest["assets"].items():
        if not re.fullmatch(r"[a-z0-9_]+", name):
            raise ValueError("Unsafe icon filename in manifest")
        target = CACHE / f"{name}.jpg"
        if not target.exists() or hashlib.sha256(target.read_bytes()).hexdigest() != asset["sha256"]:
            raise ValueError(f"Missing or changed icon {name}. Run python ui-qa/icon_assets.py --fetch.")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch", action="store_true", help="Download public metadata/artwork; subsequent rendering is offline")
    args = parser.parse_args()
    result = fetch() if args.fetch else verify()
    print(f"Verified {len(result['entities'])} spell/item records and {len(result['assets'])} cached icon images.")
