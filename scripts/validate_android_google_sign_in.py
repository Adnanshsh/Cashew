#!/usr/bin/env python3
"""Check the APK signing identity against the downloaded Google configuration."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

GUIDE = "docs/android-google-sign-in.md"


def validate_configuration(config, package, sha1):
    """Validate registration metadata, without inventing OAuth registrations."""
    if not isinstance(config, dict) or not isinstance(config.get("client"), list):
        raise ValueError("google-services.json must contain a client list")
    matching = []
    for client in config["client"]:
        if not isinstance(client, dict):
            raise ValueError("Invalid client in google-services.json")
        info = client.get("client_info", {})
        if not isinstance(info, dict):
            raise ValueError("Invalid client_info in google-services.json")
        android = info.get("android_client_info", {})
        if not isinstance(android, dict):
            raise ValueError("Invalid android_client_info in google-services.json")
        if android.get("package_name") == package:
            matching.append(client)
    if not matching:
        raise ValueError(f"No Firebase Android client for applicationId {package}")
    android_registered = web_registered = False
    for client in matching:
        oauth_clients = client.get("oauth_client", [])
        if not isinstance(oauth_clients, list):
            raise ValueError("oauth_client must be a list")
        for oauth in oauth_clients:
            if not isinstance(oauth, dict):
                raise ValueError("Invalid OAuth client in google-services.json")
            client_id = oauth.get("client_id")
            if not isinstance(client_id, str) or not client_id.endswith(".apps.googleusercontent.com"):
                raise ValueError("Missing or invalid OAuth client_id")
            if oauth.get("client_type") == 3:
                web_registered = True
            if oauth.get("client_type") == 1:
                android = oauth.get("android_info", {})
                if not isinstance(android, dict):
                    raise ValueError("Invalid OAuth android_info")
                certificate = android.get("certificate_hash", "")
                if not isinstance(certificate, str):
                    raise ValueError("Invalid Android OAuth certificate_hash")
                fingerprint = certificate.replace(":", "").upper()
                android_registered |= android.get("package_name") == package and fingerprint == sha1
    if not android_registered:
        raise ValueError(f"Signing SHA-1 is not registered for {package} in an Android OAuth client (type 1)")
    if not web_registered:
        raise ValueError("Missing web OAuth client (type 3); an Android client ID cannot replace it")


def summary(text):
    print(text)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as output:
            output.write(text + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keytool", default=shutil.which("keytool"), help="Java keytool executable path")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    try:
        gradle = (root / "budget/android/app/build.gradle").read_text(encoding="utf-8")
        app_id = re.search(r'^\s*applicationId\s*(?:=\s*)?[\"\']([^\"\']+)[\"\']\s*$', gradle, re.MULTILINE)
        if not app_id:
            raise ValueError("Cannot read a literal applicationId from budget/android/app/build.gradle")
        package = app_id.group(1)
        config = json.loads((root / "budget/android/app/google-services.json").read_text(encoding="utf-8"))
        if not args.keytool:
            raise ValueError("Java keytool was not found; use --keytool PATH")
        result = subprocess.run([args.keytool, "-exportcert", "-keystore",
                                 str(root / "budget/android/app/debug.keystore"),
                                 "-alias", "androiddebugkey", "-storepass", "android"],
                                capture_output=True, check=True)
        if not result.stdout:
            raise ValueError("keytool returned an empty signing certificate")
        sha1 = hashlib.sha1(result.stdout).hexdigest().upper()
        sha256 = hashlib.sha256(result.stdout).hexdigest().upper()
        format_sha = lambda value: ":".join(value[i:i + 2] for i in range(0, len(value), 2))
        summary(f"### Android Google Sign-In signing identity\n\nPackage: `{package}`\n\n"
                f"SHA-1: `{format_sha(sha1)}`\n\nSHA-256: `{format_sha(sha256)}`\n\nRemediation: `{GUIDE}`")
        validate_configuration(config, package, sha1)
        summary("\nGoogle Sign-In configuration matches the checked-in signing certificate. Console settings and device sign-in still require verification.")
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        summary(f"\nGoogle Sign-In configuration check failed: {error}\n\nSee `{GUIDE}`. Register the real signing certificate in Firebase/Google Cloud, then download google-services.json again.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
