#!/usr/bin/env python3
"""Archive a verified old SDK/Adapter cache before a pinned dependency upgrade.
Usage: python3 scripts/archive-verified-sdk.py ARCHIVE_DIRECTORY
Requires existing .build dependency checkouts and sdk-inventory.json. Validates
all old SDK bytes/provenance and vendor Swift files against the old Adapter
checkout before moving anything. Writes only supplied archive and local cache;
never removes archives, reads credentials, publishes or changes app data.
Restore: move archive SDK/inventory/vendor back after restoring old lock.
Codex258 / 2026-10-29.
"""
from pathlib import Path
import importlib.util,json,hashlib,subprocess,shutil,sys
sys.dont_write_bytecode=True
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('bootstrap',root/'scripts/bootstrap.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
out=Path(sys.argv[1]).resolve();assert not out.exists(),'archive already exists'
k=root/'.build/dependencies/kernel';a=root/'.build/dependencies/adapter';sdk=k/'Clash.xcframework';receipt=k.parent/'sdk-inventory.json';vendor=root/'Vendor/ClashAdapter'
old=subprocess.check_output(['git','rev-parse','HEAD'],cwd=k,text=True).strip();adapter=subprocess.check_output(['git','rev-parse','HEAD'],cwd=a,text=True).strip()
assert json.loads(receipt.read_text())==b.inventory(sdk),'SDK has unrecorded changes';b.verify_sdk(sdk,old)
for f in (vendor/'Sources/ClashAdapter').glob('*.swift'):
 assert f.read_bytes()==(a/'Sources/ClashAdapter'/f.name).read_bytes(),'vendor changed: '+f.name
assert (vendor/'LICENSE').read_bytes()==(a/'LICENSE').read_bytes()
meta={'date':'2026-10-29','task':258,'kernel':old,'adapter':adapter,'inventory_sha256':hashlib.sha256(receipt.read_bytes()).hexdigest(),'sdk_bytes_verified':True,'vendor_bytes_verified':True,'restore':'restore old lock and move these three paths back; no pruning'}
out.mkdir(parents=True)
for path,name in [(sdk,'Clash.xcframework'),(receipt,'sdk-inventory.json'),(vendor,'ClashAdapter')]:shutil.move(str(path),str(out/name))
(out/'archive-manifest.json').write_text(json.dumps(meta,indent=2));print(json.dumps(meta))
