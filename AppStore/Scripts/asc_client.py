"""App Store Connect client for A56 preparation; credentials stay in the environment."""
import os
import time
from pathlib import Path
import jwt
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

ROOT = Path(__file__).resolve().parents[2]


class Connect:
    def __init__(self):
        for key in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH"):
            if not os.environ.get(key):
                raise RuntimeError(f"Missing environment variable {key}")
        self.session = requests.Session()
        self.session.mount("https://", HTTPAdapter(max_retries=Retry(
            total=3, connect=3, read=0, status=0, backoff_factor=1
        )))
        self.expiry = 0

    def request(self, method, path, **kwargs):
        if not path.startswith("/v1/"):
            raise RuntimeError("Only App Store Connect v1 resources are supported")
        if time.time() > self.expiry - 60:
            now = int(time.time())
            self.expiry = now + 1100
            key_path = Path(os.environ["ASC_KEY_PATH"]).expanduser()
            token = jwt.encode(
                {"iss": os.environ["ASC_ISSUER_ID"], "iat": now,
                 "exp": self.expiry, "aud": "appstoreconnect-v1"},
                key_path.read_text(), algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"]}
            )
            self.session.headers["Authorization"] = "Bearer " + token
        response = self.session.request(
            method, "https://api.appstoreconnect.apple.com" + path, timeout=(12, 90), **kwargs
        )
        if not response.ok:
            # Never dump headers, JWTs, signed upload URLs or arbitrary response bodies.
            raise RuntimeError(f"App Store Connect {method} failed: HTTP {response.status_code}")
        return response.json() if response.content else {}

    def get(self, path, **params):
        return self.request("GET", path, params=params)

    def context(self):
        apps = self.get("/v1/apps", **{
            "filter[bundleId]": "com.giovannimonaco.TangenzialeNapoli"
        })["data"]
        if len(apps) != 1 or apps[0]["id"] != "6782002695":
            raise RuntimeError("Expected the existing A56 app record")
        app = apps[0]
        versions = self.get(f"/v1/apps/{app['id']}/appStoreVersions", **{
            "filter[platform]": "IOS"
        })["data"]
        version = next(v for v in versions if v["attributes"]["versionString"] == "1.0")
        return app, version
