"""Validate the app's App Store profile and configure manual signing on CI."""

import datetime
import os
from pathlib import Path
import plistlib
import re
import shutil


def prepare():
    temp = Path(os.environ['RUNNER_TEMP'])
    app = Path(os.environ['APP_PATH'])
    bundle_id = os.environ['BUNDLE_ID']
    team = os.environ['IOS_TEAM_ID']
    if not re.fullmatch(r'[A-Z0-9]{10}', team):
        raise ValueError('IOS_TEAM_ID must be the 10-character Apple Team ID')
    with (temp / 'profile.plist').open('rb') as handle:
        profile = plistlib.load(handle)
    entitlements = profile['Entitlements']
    prefix = profile['ApplicationIdentifierPrefix'][0]
    if entitlements.get('application-identifier') != f'{prefix}.{bundle_id}':
        raise ValueError(f'Provisioning profile must be for {bundle_id}')
    if team not in profile['TeamIdentifier']:
        raise ValueError('Provisioning profile belongs to a different Apple team')
    if profile['ExpirationDate'] <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
        raise ValueError('Provisioning profile has expired')
    if (profile.get('ProvisionedDevices') or profile.get('ProvisionsAllDevices')
            or entitlements.get('get-task-allow')):
        raise ValueError('Use an App Store Connect distribution profile, not development/ad hoc/enterprise')
    uuid = profile['UUID']
    if not re.fullmatch(r'[A-Fa-f0-9-]{36}', uuid):
        raise ValueError('Invalid provisioning profile UUID')
    destination = Path.home() / 'Library/MobileDevice/Provisioning Profiles' / f'{uuid}.mobileprovision'
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(temp / 'profile.mobileprovision', destination)
    (temp / 'installed-profile-path').write_text(str(destination), encoding='utf-8')
    (app / 'ios/Flutter/Signing.xcconfig').write_text(
        f'DEVELOPMENT_TEAM = {team}\n'
        'CODE_SIGN_STYLE = Manual\n'
        'CODE_SIGN_IDENTITY = Apple Distribution\n'
        f'PROVISIONING_PROFILE_SPECIFIER = {uuid}\n', encoding='utf-8')
    options = {
        'method': 'app-store-connect',
        'teamID': team,
        'signingStyle': 'manual',
        'signingCertificate': 'Apple Distribution',
        'provisioningProfiles': {bundle_id: uuid},
        'manageAppVersionAndBuildNumber': False,
        'uploadSymbols': True,
    }
    with (temp / 'ExportOptions.plist').open('wb') as handle:
        plistlib.dump(options, handle)
    print(f'Configured App Store signing for {bundle_id}')


if __name__ == '__main__':
    prepare()
