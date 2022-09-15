import json
import os
from typing import Tuple
import requests

API_URL = "https://api.up.com.au/api/v1"

player_1_token = os.environ.get("TOKEN1")
player_2_token = os.environ.get("TOKEN2")

def get_from(url: str, token:str) -> dict:
    return requests.get(url, headers={"Authorization": f"Bearer {token}"}).json()

def get_from_api(endpoint: str, token: str) -> dict:
    return requests.get(f"{API_URL}/{endpoint}", headers={"Authorization": f"Bearer {token}"}).json()

def map_account_ids_to_names(account_json: dict) -> dict[str, str]:
    accounts: list = account_json["data"]
    ids_to_names = {}

    for account in accounts:
        ids_to_names[account["id"]] = account["attributes"]["displayName"]
    
    return ids_to_names

def extract_account_ids(account_json: dict) -> Tuple[list[str], list[str]]:
    accounts: list = account_json["data"]
    ids = []
    _2up_ids = []
    for account in accounts:
        if account["attributes"]["ownershipType"] == "JOINT":
            _2up_ids.append(account["id"])
        else:
            ids.append(account["id"])

    return (ids, _2up_ids)


def get_shared_transactions(shared_account_ids: list[str]) -> dict[str, list[dict]]:
    print(f"Shared account ids: {shared_account_ids}")
    shared_transactions : dict[str, list[dict]] = {}

    # doesn't account for pagination
    for id in shared_account_ids:
        response = get_from_api(
            f"accounts/{id}/transactions", player_1_token)
        shared_transactions[id] = response["data"]
        
        while response["links"]["next"] is not None:
            print(response["links"]["next"])

            response = get_from( 
            response["links"]["next"], player_1_token)
            
            shared_transactions[id].extend(response["data"])


    return shared_transactions


def get_cash_flow_by_player(transactions: list[dict], player_1_accounts_ids: list[str], player_2_account_ids: list[str]) -> Tuple[Tuple[int, int], Tuple[int, int], Tuple[int, int]]:
    player_1_cashflow = (0, 0)
    player_2_cashflow = (0, 0)
    unaccounted_cashflow = (0, 0)

    # print(f"Transactions length {len(transactions)}")

    for t in transactions:
        value_in_base_units = int(
            t["attributes"]["amount"]["valueInBaseUnits"])
        #print(value_in_base_units)

        transfer_account: dict = t["relationships"]["transferAccount"]

        if transfer_account.get('data') is not None:
            transfer_account_id : str = transfer_account["data"]["id"]
            #print(f"transfer account id: {transfer_account_id}")

            if transfer_account_id in player_1_accounts_ids:
                if value_in_base_units > 0:
                    player_1_cashflow = (
                        player_1_cashflow[0] + value_in_base_units, player_1_cashflow[1])
                else:
                    player_1_cashflow = (
                        player_1_cashflow[0], player_1_cashflow[1] + value_in_base_units)
            elif transfer_account_id in player_2_account_ids:
                if value_in_base_units > 0:
                    player_2_cashflow = (
                        player_2_cashflow[0] + value_in_base_units, player_2_cashflow[1])
                else:
                    player_2_cashflow = (
                        player_2_cashflow[0], player_2_cashflow[1] + value_in_base_units)
            else:
                if value_in_base_units > 0:
                    unaccounted_cashflow = (
                        unaccounted_cashflow[0] + value_in_base_units, unaccounted_cashflow[1])
                else:
                    unaccounted_cashflow = (
                        unaccounted_cashflow[0], unaccounted_cashflow[1] + value_in_base_units)
        else:
            if value_in_base_units > 0:
                unaccounted_cashflow = (
                    unaccounted_cashflow[0] + value_in_base_units, unaccounted_cashflow[1])
            else:
                unaccounted_cashflow = (
                    unaccounted_cashflow[0], unaccounted_cashflow[1] + value_in_base_units)

    return (player_1_cashflow, player_2_cashflow, unaccounted_cashflow)


def main():
    player_1_accounts_json = get_from_api("accounts", player_1_token)
    player_2_accounts_json = get_from_api("accounts", player_2_token)

    player_1_account_ids = extract_account_ids(
        player_1_accounts_json)
    player_2_account_ids = extract_account_ids(
        player_2_accounts_json)

    player_1_account_name_map = map_account_ids_to_names(player_1_accounts_json)
    player_2_account_name_map = map_account_ids_to_names(player_2_accounts_json)

    print(f"player 1 acc ids: {player_1_account_ids[0]}")
    print(f"player 2 acc ids: {player_2_account_ids[0]}")

    if player_1_account_ids[1] != player_2_account_ids[1]:
        print("Joint account mismatch. Quitting")
        exit()
    else:
        print("Joint accounts match! Continuing...")

    shared_transactions_by_account = get_shared_transactions(player_1_account_ids[1])

    for st in shared_transactions_by_account:
        print(player_1_account_name_map[st])
        print(get_cash_flow_by_player(
            shared_transactions_by_account[st], player_1_account_ids[0], player_2_account_ids[0]))


if __name__ == "__main__":
    main()
