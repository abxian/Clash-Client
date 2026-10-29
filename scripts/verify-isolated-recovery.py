#!/usr/bin/env python3
"""Verify the running DEBUG app against isolated-api-fixture recovery controls.
Python3 + Xcode simctl; device name must be Shenxianyun iPhone258. Requires
loopback fixture --state/--control and an already imported fixture211 in the
foreground, with SXY_TEST_API_BASE enabled. Never launches a VPN or changes app
preferences. Only reads that dedicated fake container and writes fixture
control + output. Polls boundedly so the real foreground monitor does the work.
Usage: python3 scripts/verify-isolated-recovery.py --device UUID --fixture-state
.build/state.json --control .build/control.json --output RESULT.json
Rollback: remove own control, stop own fixture/app; no user data/reset/deletion.
Source: Codex258,2026-10-29. All account values are synthetic, secrets unprinted.
"""
from pathlib import Path
import argparse,subprocess,json,plistlib,hashlib,time
from urllib.parse import urlsplit
p=argparse.ArgumentParser();p.add_argument('--device',required=True);p.add_argument('--fixture-state',type=Path,required=True);p.add_argument('--control',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1]
assert a.control.resolve().is_relative_to((root/'.build').resolve())
assert a.fixture_state.resolve().is_relative_to((root/'.build').resolve())
devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json']))['devices'];device=next(d for ds in devices.values() for d in ds if d['udid']==a.device);assert device['name']=='Shenxianyun iPhone258' and device['state']=='Booted'
f=json.loads(a.fixture_state.read_text());assert urlsplit(f['base']).hostname=='127.0.0.1'
container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.device,'de.sxnn.shenxianyun','data'],text=True).strip());defaults=container/'Library/Preferences/group.de.sxnn.shenxianyun.plist';qa=container/'Library/Application Support/ShenxianyunIsolatedQA'
assert qa.exists()
def snapshot():
 d=plistlib.loads(defaults.read_bytes());assert d.get('shenxianyun.access_code')=='fixture211'
 activation=json.loads(d['shenxianyun.activation']);assert activation['deviceToken']=='fixture-device-token'
 pid=d['shenxianyun.profile_id'];source=(qa/'working/store'/pid/'source.yaml').read_text()
 return {'profile_id':pid,'credential_sha256':hashlib.sha256(d['shenxianyun.activation']).hexdigest(),'token':activation['deviceToken'],'url':activation['subscriptionURL'],'restriction':json.loads(d['shenxianyun.access_restriction']) if 'shenxianyun.access_restriction' in d else None,'recovery':json.loads(d['shenxianyun.subscription_recovery']) if 'shenxianyun.subscription_recovery' in d else None,'source':source}
def control(**kw):
 temp=a.control.with_suffix('.tmp');temp.write_text(json.dumps(kw));temp.replace(a.control)
def wait(test,label,timeout=100):
 end=time.monotonic()+timeout
 while time.monotonic()<end:
  s=snapshot()
  if test(s):print('PASS '+label,flush=True);return s
  time.sleep(1)
 raise AssertionError('bounded wait failed: '+label)
initial=wait(lambda s:s['recovery'] is not None,'initial saved revision')
rows=[]
control(restriction='expired');wait(lambda s:s['restriction'] and s['restriction']['reason']=='expired','expiry detected')
control(revision='fixture-B',version=1,expires_at='2100-01-01 00:00:00',node_name='隔离迁移节点B')
s=wait(lambda s:s['restriction'] is None and s['recovery']['revision']=='fixture-B' and '隔离迁移节点B' in s['source'],'renewal and lower-version file migration')
assert s['recovery']['version']==1;rows.append('expired -> extended; low-version revision B applied to original config')
control(restriction='traffic_limit');wait(lambda s:s['restriction'] and s['restriction']['reason']=='traffic_limit','quota restriction detected')
control(revision='fixture-B',version=1,expires_at='2100-01-01 00:00:00',node_name='隔离额度恢复C')
s=wait(lambda s:s['restriction'] is None and '隔离额度恢复C' in s['source'],'same-revision quota restored')
rows.append('same revision quota restoration redownloaded valid nodes')
control(revision='fixture-C',version=2,node_name='隔离失败保留D',fail_download=True)
count=sum(x['path']=='/managed-sub/fixture-config' for x in json.loads(a.fixture_state.read_text())['requests'])
end=time.monotonic()+100
while time.monotonic()<end:
 n=sum(x['path']=='/managed-sub/fixture-config' for x in json.loads(a.fixture_state.read_text())['requests'])
 if n>count:break
 time.sleep(1)
else:raise AssertionError('failed download was not attempted')
time.sleep(3);s=snapshot();assert s['recovery']['revision']=='fixture-B' and '隔离额度恢复C' in s['source'];print('PASS failed download preserved source/revision',flush=True);rows.append('503 download does not consume revision or remove last good source')
control(revision='fixture-C',version=2,node_name='隔离重试恢复D')
s=wait(lambda s:s['recovery']['revision']=='fixture-C' and '隔离重试恢复D' in s['source'],'failed download retries and recovers',timeout=120);rows.append('recovery after 503 using existing credentials')
assert s['profile_id']==initial['profile_id'] and s['token']==initial['token'] and s['url']==initial['url']
f=json.loads(a.fixture_state.read_text());exchanges=sum(x['path']=='/api/import/exchange' for x in f['requests']);assert exchanges==1
result={'date':'2026-10-29','result':'pass','source':'8ba3385','device':a.device,'platform':'iPhone17Pro iOS26.5 Simulator','scenarios':rows,'profile_id_unchanged':True,'credential_and_url_unchanged':True,'ticket_exchange_count':exchanges,'production_data':False,'real_vpn_started':False,'scope':'actual running DEBUG app with loopback fake state and real source/revision persistence; not payment/network-extension validation'}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2));print(json.dumps(result),flush=True)
