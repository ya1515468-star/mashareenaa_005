#!/usr/bin/env python3
from pathlib import Path
import re, sys

ROOT = Path(__file__).resolve().parents[1]
EXCLUDE_DIRS = {'.git', '.dart_tool', 'build', 'coverage'}
SECRET_PATTERNS = [
    (re.compile(r'BEGIN (?:RSA|EC|OPENSSH|PRIVATE) KEY'), 'private key material'),
    (re.compile(r'AIza[0-9A-Za-z_-]{20,}'), 'Google API key'),
    (re.compile(r'AKIA[0-9A-Z]{16}'), 'AWS access key'),
    (re.compile(r'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}'), 'GitHub token'),
    (re.compile(r'(?i)service_role.{0,80}[''"]eyJ'), 'Supabase service-role JWT-like secret'),
    (re.compile(r'(?i)(client_secret|private_key|access_token|refresh_token|database_url)\s*[:=]\s*[''"][A-Za-z0-9_./+=:-]{20,}'), 'credential assignment'),
]
FILENAME_PATTERNS = re.compile(r'(^|/)(?:\.env(?:\..*)?|key\.properties|.*\.(?:jks|keystore|p12|pem)|google-services\.json|GoogleService-Info\.plist|.*credentials.*\.json)$', re.I)
RISK_PATTERNS = [
    (re.compile(r'android:usesCleartextTraffic=\"true\"'), 'Android cleartext traffic enabled'),
    (re.compile(r'setJavaScriptMode\(JavaScriptMode\.unrestricted\)'), 'unrestricted WebView JavaScript'),
]

errors=[]
warnings=[]
for p in ROOT.rglob('*'):
    if not p.is_file():
        continue
    rel=p.relative_to(ROOT).as_posix()
    if any(part in EXCLUDE_DIRS for part in p.parts):
        continue
    if FILENAME_PATTERNS.search(rel):
        if rel == 'android/local.properties':
            warnings.append(f'{rel}: local-only config; should not be committed')
        else:
            errors.append(f'{rel}: sensitive filename should not be committed')
        continue
    try:
        data=p.read_text(encoding='utf-8', errors='ignore')
    except Exception:
        continue
    for rx, label in SECRET_PATTERNS:
        if rx.search(data):
            errors.append(f'{rel}: {label}')
    for rx, label in RISK_PATTERNS:
        if rx.search(data):
            warnings.append(f'{rel}: {label}')

# Allow the documented client publishable key form; it is not a server service-role key.
config = ROOT / 'lib/core/config/supabase_config.dart'
if config.exists():
    txt=config.read_text(encoding='utf-8', errors='ignore')
    if 'sb_publishable_' in txt:
        warnings.append('lib/core/config/supabase_config.dart: Supabase publishable key is client-visible by design; server/service-role keys must remain in Edge Function secrets.')

print('MASHAREENA STATIC SECURITY SCAN')
print(f'Errors: {len(errors)}')
for x in errors: print('ERROR:', x)
print(f'Warnings: {len(warnings)}')
for x in sorted(set(warnings)): print('WARN:', x)
if errors:
    sys.exit(1)
print('PASS: no high-confidence secret material detected in tracked-source scope')
