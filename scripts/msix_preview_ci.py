#!/usr/bin/env python3
"""CI-only source-built manager MSIX preview; no install, signing, registry or release."""
from __future__ import annotations
import argparse
import hashlib
import json
import shutil
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / 'packaging' / 'msix-preview' / 'Assets'
APP_SCRIPTS = (
    'ProjectShell.ps1',
    'ProjectShell.Workspaces.ps1',
    'ProjectShell.Catalogue.ps1',
    'ProjectShell.Migration.ps1',
)
LOGOS = ('StoreLogo.png', 'Square44x44Logo.png', 'Square150x150Logo.png')
NAME = 'ProjectShell.CI.Preview'
PUBLISHER = 'CN=ProjectShell CI Preview'
VERSION = '1.2.0.0'
FNS = 'http://schemas.microsoft.com/appx/manifest/foundation/windows10'
UAP = 'http://schemas.microsoft.com/appx/manifest/uap/windows10'
UAP10 = 'http://schemas.microsoft.com/appx/manifest/uap/windows10/10'
RESCAP = 'http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities'
NS = {'p': FNS, 'uap': UAP, 'uap10': UAP10, 'rescap': RESCAP}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def manifest() -> bytes:
    return (r'''<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
         xmlns:uap10="http://schemas.microsoft.com/appx/manifest/uap/windows10/10"
         xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
         IgnorableNamespaces="uap10">
  <Identity Name="ProjectShell.CI.Preview" Publisher="CN=ProjectShell CI Preview"
            Version="1.2.0.0" ProcessorArchitecture="x64" />
  <Properties>
    <DisplayName>ProjectShell CI Structural Preview</DisplayName>
    <PublisherDisplayName>ProjectShell Development</PublisherDisplayName>
    <Description>Not signed, install-tested or approved for public distribution</Description>
    <Logo>Assets\StoreLogo.png</Logo>
  </Properties>
  <Resources><Resource Language="en-US" /></Resources>
  <Dependencies><TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.19041.0" MaxVersionTested="10.0.26100.0" /></Dependencies>
  <Capabilities><rescap:Capability Name="runFullTrust" /></Capabilities>
  <Applications>
    <Application Id="ProjectShell" Executable="ProjectShell-Manager.exe"
                 uap10:RuntimeBehavior="packagedClassicApp" uap10:TrustLevel="mediumIL">
      <uap:VisualElements DisplayName="ProjectShell CI Structural Preview"
                          Description="Temporary nonpublishing ProjectShell manager package"
                          Square150x150Logo="Assets\Square150x150Logo.png"
                          Square44x44Logo="Assets\Square44x44Logo.png"
                          BackgroundColor="#1A263F" />
    </Application>
  </Applications>
</Package>
''').encode('utf-8')


def check_manifest(data: bytes) -> None:
    root = ET.fromstring(data)
    if root.tag != '{%s}Package' % FNS:
        raise ValueError('Invalid manifest root')
    identity = root.find('p:Identity', NS)
    if identity is None or any(identity.get(k) != v for k, v in {
        'Name': NAME, 'Publisher': PUBLISHER, 'Version': VERSION,
        'ProcessorArchitecture': 'x64',
    }.items()):
        raise ValueError('Unexpected MSIX CI identity')
    app = root.find('p:Applications/p:Application', NS)
    if app is None or any(app.get(k) != v for k, v in {
        'Executable': 'ProjectShell-Manager.exe',
        '{%s}RuntimeBehavior' % UAP10: 'packagedClassicApp',
        '{%s}TrustLevel' % UAP10: 'mediumIL',
    }.items()):
        raise ValueError('Invalid manager launch entry')
    capability = root.find('p:Capabilities/rescap:Capability', NS)
    if capability is None or capability.get('Name') != 'runFullTrust':
        raise ValueError('Missing restricted full-trust capability')
    visuals = app.find('uap:VisualElements', NS)
    if visuals is None or visuals.get('Square150x150Logo') != r'Assets\Square150x150Logo.png':
        raise ValueError('Invalid app visual assets')


def required_inputs(source: Path, manager: Path) -> None:
    if not manager.is_file() or manager.stat().st_size == 0:
        raise FileNotFoundError('Source-built Manager EXE missing')
    for name in APP_SCRIPTS:
        if not (source/name).is_file():
            raise FileNotFoundError(f'Missing application source: {name}')
    for name in LOGOS:
        if not (ASSETS/name).is_file():
            raise FileNotFoundError(f'Missing temporary preview icon: {name}')
    if (b'ProjectShell.ps1' not in manager.read_bytes()
        and 'ProjectShell.ps1'.encode('utf-16le') not in manager.read_bytes()):
        raise ValueError('Manager executable does not reference ProjectShell.ps1')
    check_manifest(manifest())


def stage(source: Path, manager: Path, out: Path) -> None:
    required_inputs(source, manager)
    if out.exists():
        raise FileExistsError(f'Refusing to overwrite stage: {out}')
    out.mkdir(parents=True)
    (out/'Assets').mkdir()
    shutil.copyfile(manager, out/'ProjectShell-Manager.exe')
    for name in APP_SCRIPTS:
        shutil.copyfile(source/name, out/name)
    for name in LOGOS:
        shutil.copyfile(ASSETS/name, out/'Assets'/name)
    (out/'AppxManifest.xml').write_bytes(manifest())
    print('CI MSIX STAGED: source-built manager + 4 scripts + temporary assets')


def verify(source: Path, manager: Path, package: Path, receipt: Path) -> None:
    required_inputs(source, manager)
    if not package.is_file():
        raise FileNotFoundError('MSIX package missing')
    expected_names = {'AppxManifest.xml', 'AppxBlockMap.xml', '[Content_Types].xml',
                      'ProjectShell-Manager.exe'} | set(APP_SCRIPTS) | {'Assets/'+x for x in LOGOS}
    with zipfile.ZipFile(package) as z:
        if z.testzip() is not None:
            raise ValueError('MSIX corrupted')
        names = {name.replace('\\', '/'): name for name in z.namelist()}
        if not expected_names.issubset(names):
            raise ValueError('Missing MSIX payload files: '+repr(sorted(expected_names-set(names))))
        if 'AppxSignature.p7x' in names:
            raise ValueError('Unexpected signature on preview package')
        check_manifest(z.read(names['AppxManifest.xml']))
        for name, original in [('ProjectShell-Manager.exe', manager)] + [
            (name, source/name) for name in APP_SCRIPTS
        ] + [('Assets/'+name, ASSETS/name) for name in LOGOS]:
            actual = hashlib.sha256(z.read(names[name])).hexdigest().upper()
            if actual != digest(original):
                raise ValueError('Package content differs from CI source-built input: '+name)
    result = {
        'status': 'CI_MSIX_STRUCTURAL_VERIFIED',
        'package': str(package), 'sha256': digest(package),
        'manager_sha256': digest(manager),
        'identity': NAME, 'publisher': PUBLISHER,
        'source_derived': True, 'signed': False, 'installed': False,
        'runtime_msix_verified': False, 'store_ready': False,
        'published': False,
    }
    if receipt.exists():
        raise FileExistsError('Refusing to overwrite acceptance receipt')
    receipt.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print('PASS: Nonpublishing MSIX structural verification')
    print('SHA256: '+result['sha256'])
    print('Receipt: '+str(receipt))


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument('action', choices=['stage', 'verify'])
    p.add_argument('--source', required=True, type=Path)
    p.add_argument('--manager', required=True, type=Path)
    p.add_argument('--stage', type=Path)
    p.add_argument('--package', type=Path)
    p.add_argument('--receipt', type=Path)
    args = p.parse_args()
    if args.action == 'stage':
        if args.stage is None:
            p.error('stage requires --stage')
        stage(args.source, args.manager, args.stage)
    else:
        if args.package is None or args.receipt is None:
            p.error('verify requires --package and --receipt')
        verify(args.source, args.manager, args.package, args.receipt)


if __name__ == '__main__':
    main()
