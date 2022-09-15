import os
import requests
from dataclasses import dataclass

API_URL = "https://api.up.com.au/api/v1"

player_1_token = os.environ.get("TOKEN1")
player_2_token = os.environ.get("TOKEN2")


@dataclass
class Cashflow:
    in_flow: int
    out_flow: int

    def update(self, amount: int):
        if amount < 0:
            self.out_flow += amount
        else:
            self.in_flow += amount

    def add(self, cf):
        self.in_flow += cf.in_flow
        self.out_flow += cf.out_flow

    def __str__(self) -> str:
        return f"In: {format_currency(self. in_flow)}, Out: {format_currency(self.out_flow)}"


@dataclass
class AccountByPlayer:
    account_id: str
    player_1_cashflow: Cashflow
    player_2_cashflow: Cashflow
    unaccounted_cashflow: Cashflow
    shared_cashflows: dict[str, Cashflow]


@dataclass
class PlayerAccountIds:
    individual_accounts: list[str]
    joint_accounts: list[str]


def get_from(url: str, token: str) -> dict:
    return requests.get(url, headers={"Authorization": f"Bearer {token}"}).json()


def get_from_api(endpoint: str, token: str) -> dict:
    response = requests.get(f"{API_URL}/{endpoint}",
                            headers={"Authorization": f"Bearer {token}"})

    if response.status_code == 200:
        return response.json()
    elif response.status_code == 401:
        print("Token not authorised.")
        return {}
    else:
        print(f"Reponse returned status {response.status_code}")
        return {}


def map_account_ids_to_names(account_json: dict) -> dict[str, str]:
    accounts: list = account_json["data"]
    ids_to_names = {}

    for account in accounts:
        ids_to_names[account["id"]] = account["attributes"]["displayName"]

    return ids_to_names


def extract_account_ids(account_json: dict) -> PlayerAccountIds:
    accounts: list = account_json["data"]
    ids: list[str] = []
    _2up_ids: list[str] = []
    for account in accounts:
        if account["attributes"]["ownershipType"] == "JOINT":
            _2up_ids.append(account["id"])
        else:
            ids.append(account["id"])

    return PlayerAccountIds(ids, _2up_ids)


def get_shared_transactions(shared_account_ids: list[str]) -> dict[str, list[dict]]:
    shared_transactions: dict[str, list[dict]] = {}

    # doesn't account for pagination
    for id in shared_account_ids:
        response = get_from_api(
            f"accounts/{id}/transactions", player_1_token)
        shared_transactions[id] = response["data"]

        while response["links"]["next"] is not None:
            response = get_from(
                response["links"]["next"], player_1_token)

            shared_transactions[id].extend(response["data"])

    return shared_transactions


def get_cash_flow_by_player(account_id: str, transactions: list[dict], player_1_accounts_ids: PlayerAccountIds, player_2_account_ids: PlayerAccountIds) -> AccountByPlayer:
    player_1_cashflow = Cashflow(0, 0)
    player_2_cashflow = Cashflow(0, 0)
    _2up_internal_cashflow: dict[str, Cashflow] = {}
    unaccounted_cashflow = Cashflow(0, 0)

    for ja_id in player_1_accounts_ids.joint_accounts:
        _2up_internal_cashflow[ja_id] = Cashflow(0, 0)

    # print(f"Transactions length {len(transactions)}")

    for t in transactions:
        value_in_base_units = int(
            t["attributes"]["amount"]["valueInBaseUnits"])
        # print(value_in_base_units)

        transfer_account: dict = t["relationships"]["transferAccount"]

        if transfer_account.get('data') is not None:
            transfer_account_id: str = transfer_account["data"]["id"]
            #print(f"transfer account id: {transfer_account_id}")

            if transfer_account_id in player_1_accounts_ids.individual_accounts:
                player_1_cashflow.update(value_in_base_units)
            elif transfer_account_id in player_2_account_ids.individual_accounts:
                player_2_cashflow.update(value_in_base_units)
            elif transfer_account_id in _2up_internal_cashflow.keys():
                _2up_internal_cashflow[transfer_account_id].update(
                    value_in_base_units)
        else:
            unaccounted_cashflow.update(value_in_base_units)
    return AccountByPlayer(account_id, player_1_cashflow, player_2_cashflow, unaccounted_cashflow, _2up_internal_cashflow)


def format_currency(cents: int) -> str:
    return '${:,.2f}'.format(cents / 100)


def pretty_print_account_cashflow(account: AccountByPlayer, player_1_account_names: dict[str, str]) -> None:
    print("-" * 40)
    print(f"Source account: {player_1_account_names[account.account_id]}")

    print(f"Player 1 Contribution     \t {account.player_1_cashflow}")
    print(f"Player 2 Contribution     \t {account.player_2_cashflow}")
    print(f"Unaccounted Contribution  \t {account.unaccounted_cashflow}")

    print("\n2UP Internal Cashflows: ")
    for sa in account.shared_cashflows:
        if sa is not account.account_id:
            cf = account.shared_cashflows[sa]

            print(f"Account: {player_1_account_names[sa]}")
            print(f"{cf}")

    print("-" * 40 + "\n")
    pass


def main():
    player_1_accounts_json = get_from_api("accounts", player_1_token)
    player_2_accounts_json = get_from_api("accounts", player_2_token)

    if player_1_accounts_json == {} or player_2_accounts_json == {}:
        if player_1_accounts_json == {}:
            print("Couldn't get player 1 data. Token is possibly wrong or invalid.")
        if player_2_accounts_json == {}:
            print("Couldn't get player 2 data. Token is possibly wrong or invalid.")
        print("Quitting!")
        exit()

    player_1_account_ids = extract_account_ids(
        player_1_accounts_json)
    player_2_account_ids = extract_account_ids(
        player_2_accounts_json)

    player_1_account_name_map = map_account_ids_to_names(
        player_1_accounts_json)

    print(f"Player 1 acc ids: {player_1_account_ids.individual_accounts}")
    print(f"Player 2 acc ids: {player_2_account_ids.individual_accounts}")
    print(f"Shared account ids: {player_1_account_ids.joint_accounts}")
    if player_1_account_ids.joint_accounts != player_2_account_ids.joint_accounts:
        print("Joint account mismatch. Quitting")
        exit()
    else:
        print("Joint accounts match! Continuing...")

    shared_transactions_by_account = get_shared_transactions(
        player_1_account_ids.joint_accounts)

    total_player_1_cashflow = Cashflow(0, 0)
    total_player_2_cashflow = Cashflow(0, 0)
    total_unaccounted_cashflow = Cashflow(0, 0)
    for st in shared_transactions_by_account:
        abp = get_cash_flow_by_player(st,
                                      shared_transactions_by_account[st], player_1_account_ids, player_2_account_ids)

        total_player_1_cashflow.add(abp.player_1_cashflow)
        total_player_2_cashflow.add(abp.player_2_cashflow)
        total_unaccounted_cashflow.add(abp.unaccounted_cashflow)

        pretty_print_account_cashflow(
            abp, player_1_account_name_map)

    print("\nTotals:")
    print(f"Total player 1 contribution {total_player_1_cashflow}")
    print(f"Total player 2 contribution {total_player_2_cashflow}")
    print(f"Total unaccounted contribution {total_unaccounted_cashflow}")


if __name__ == "__main__":
    main()
