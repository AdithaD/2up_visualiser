import json
import os
from typing import Tuple
import requests

API_URL = "https://api.up.com.au/api/v1"

token_1 = os.environ.get("TOKEN1")
token_2 = os.environ.get("TOKEN2")

print(token_1)

def get_from_api(endpoint: str, token : str) -> dict:
    return requests.get(f"{API_URL}/{endpoint}", headers={"Authorization": f"Bearer {token}"}).json()

def extract_account_ids(account_json: dict) -> Tuple[list[str], str]:
    accounts : list = account_json["data"]
    ids = []
    _2up_id = ""
    for account in accounts:
        if account["attributes"]["ownershipType"] == "JOINT":
            _2up_id = account["id"]
        else:
            ids.append(account["id"])

    return (ids, _2up_id)

accounts_1 = get_from_api("accounts", token_1)
print(extract_account_ids(accounts_1))

accounts_2 = get_from_api("accounts", token_2)
print(extract_account_ids(accounts_2))