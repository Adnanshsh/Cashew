import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from validate_android_google_sign_in import validate_configuration

PACKAGE = "com.budget.tracker_app"
SHA1 = "0123456789ABCDEF0123456789ABCDEF01234567"
ANDROID = {"client_type": 1, "client_id": "123-android.apps.googleusercontent.com",
           "android_info": {"package_name": PACKAGE, "certificate_hash": SHA1.lower()}}
WEB = {"client_type": 3, "client_id": "123-web.apps.googleusercontent.com"}


def configuration(*oauth_clients, package=PACKAGE):
    return {"client": [{"client_info": {"android_client_info": {"package_name": package}},
                        "oauth_client": list(oauth_clients)}]}


class GoogleSignInConfigurationTests(unittest.TestCase):
    def test_registered_certificate_and_web_client_pass(self):
        validate_configuration(configuration(ANDROID, WEB), PACKAGE, SHA1)

    def test_other_signing_certificates_and_platforms_are_allowed(self):
        other = copy.deepcopy(ANDROID)
        other["android_info"]["certificate_hash"] = "F" * 40
        ios = {"client_type": 2, "client_id": "123-ios.apps.googleusercontent.com"}
        config = configuration(other, ios, ANDROID, WEB)
        config["client"].append(configuration(WEB, package="com.other.app")["client"][0])
        validate_configuration(config, PACKAGE, SHA1)

    def test_missing_or_different_signing_sha1_fails(self):
        for fingerprint in ("", "F" * 40):
            android = copy.deepcopy(ANDROID)
            android["android_info"]["certificate_hash"] = fingerprint
            with self.subTest(fingerprint=fingerprint), self.assertRaisesRegex(ValueError, "Signing SHA-1"):
                validate_configuration(configuration(android, WEB), PACKAGE, SHA1)

    def test_wrong_package_at_either_level_fails(self):
        android = copy.deepcopy(ANDROID)
        android["android_info"]["package_name"] = "com.other.app"
        for config in (configuration(ANDROID, WEB, package="com.other.app"), configuration(android, WEB)):
            with self.subTest(config=config), self.assertRaises(ValueError):
                validate_configuration(config, PACKAGE, SHA1)

    def test_web_and_android_client_types_are_not_interchangeable(self):
        for clients in ((WEB,), (ANDROID,)):
            with self.subTest(clients=clients), self.assertRaises(ValueError):
                validate_configuration(configuration(*clients), PACKAGE, SHA1)

    def test_malformed_and_missing_metadata_fail(self):
        for config in ({}, {"client": None}, {"client": [None]}, configuration(),
                       configuration({"client_type": 3}),
                       configuration({"client_type": 1, "client_id": WEB["client_id"], "android_info": None})):
            with self.subTest(config=config), self.assertRaises(ValueError):
                validate_configuration(config, PACKAGE, SHA1)


if __name__ == "__main__":
    unittest.main()
