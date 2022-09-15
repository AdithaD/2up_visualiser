import os
import requests
from dataclasses import dataclass

API_URL = "https://api.up.com.au/api/v1"

# Loading environment variables

player_1_token = os.environ.get("TOKEN1")
player_2_token = os.environ.get("TOKEN2")

@dataclass
class Cashflow:
    """
    Represents the sums of incoming transaction values and outgoing transaction values
    """
    in_flow: int
    out_flow: int

    
    def update(self, amount: int):
        """Updates `in_flow` if positive and `outflow` if negative."""
        if amount < 0:
            self.out_flow += amount
        else:
            self.in_flow += amount

    def __add__(self, cf):
        return Cashflow(self.in_flow + cf.in_flow, self.out_flow + cf.out_flow)

        
    def __iadd__(self, cf):
        self.in_flow += cf.in_flow
        self.out_flow += cf.out_flow
        return self

    def __str__(self) -> str:
        return f"In: {format_currency(self. in_flow)}, Out: {format_currency(self.out_flow)}"


@dataclass
class AccountByPlayer:
    """
    Breaks down account cashflow into an account by player, other 2UP accounts and unaccounted for transactions.
    
    """
    account_id: str
    player_1_cashflow: Cashflow
    player_2_cashflow: Cashflow
    unaccounted_cashflow: Cashflow
    shared_cashflows: dict[str, Cashflow]


@dataclass
class PlayerAccountIds:
    """Holds the unique ids of a Player's individual accounts and joint accounts"""
    individual_accounts: list[str]
    joint_accounts: list[str]


def get_from(url: str, token: str) -> dict:
    """Returns the JSON body of a GET request at `url` with Bearer Authorisation given by `token`"""
    return requests.get(url, headers={"Authorization": f"Bearer {token}"}).json()


def get_from_api(endpoint: str, token: str) -> dict:
    """Returns the JSON body of a GET request at `{UP_API_URL}/endpoint` with Bearer Authorisation given by `token`"""
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
    """Creates a `dict` that maps an unique account ID to its display name"""
    accounts: list = account_json["data"]
    ids_to_names = {}

    for account in accounts:
        ids_to_names[account["id"]] = account["attributes"]["displayName"]

    return ids_to_names


def extract_account_ids(account_json: dict) -> PlayerAccountIds:
    """Extracts the account ids from the json data from a GET request to `{UP_API_URL}/accounts"""
    accounts: list = account_json["data"]
    ids: list[str] = []
    _2up_ids: list[str] = []
    for account in accounts:
        if account["attributes"]["ownershipType"] == "JOINT":
            _2up_ids.append(account["id"])
        else:
            ids.append(account["id"])

    return PlayerAccountIds(ids, _2up_ids)


def get_joint_transactions(joint_account_ids: list[str]) -> dict[str, list[dict]]:
    """Generates a dictionary mapping joint account IDs to transactions. Automatically cycles pages to get all transactions"""
    shared_transactions: dict[str, list[dict]] = {}

    # doesn't account for pagination
    for id in joint_account_ids:
        response = get_from_api(
            f"accounts/{id}/transactions", player_1_token)
        shared_transactions[id] = response["data"]

        while response["links"]["next"] is not None:
            response = get_from(
                response["links"]["next"], player_1_token)

            shared_transactions[id].extend(response["data"])

    return shared_transactions


def get_cash_flow_by_player(account_id: str, transactions: list[dict], player_1_accounts_ids: PlayerAccountIds, player_2_account_ids: PlayerAccountIds) -> AccountByPlayer:
    """
    Processs the transactions to split total cashflow by players, 2UP internal accounts and unaccounted for transactions

        Returns:
            account_by_player (AccountByPlayer): A data structure holding the separated cashflows
    """
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
    """Formats cents into a visually pleasing currency format"""
    return '${:,.2f}'.format(cents / 100)


def pretty_print_account_by_player_cashflow(account: AccountByPlayer, player_1_account_names: dict[str, str]) -> None:
    """Prints the account by player cashflow split in a aesthetic way"""
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
    # Loads account data
    player_1_accounts_json = get_from_api("accounts", player_1_token)
    player_2_accounts_json = get_from_api("accounts", player_2_token)

    # Checks to see if the joint accounts match. Otherwise, this tool won't work.
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

    shared_transactions_by_account = get_joint_transactions(
        player_1_account_ids.joint_accounts)

    total_player_1_cashflow = Cashflow(0, 0)
    total_player_2_cashflow = Cashflow(0, 0)
    total_unaccounted_cashflow = Cashflow(0, 0)
    
    # Pretty prints the account cashflow splits whilst generating a total contribution cashflow for each player
    for st in shared_transactions_by_account:
        abp = get_cash_flow_by_player(st,
                                      shared_transactions_by_account[st], player_1_account_ids, player_2_account_ids)

        total_player_1_cashflow += abp.player_1_cashflow
        total_player_2_cashflow += abp.player_2_cashflow
        total_unaccounted_cashflow += abp.unaccounted_cashflow

        pretty_print_account_by_player_cashflow(
            abp, player_1_account_name_map)

    print("\nTotals:")
    print(f"Total player 1 contribution {total_player_1_cashflow}")
    print(f"Total player 2 contribution {total_player_2_cashflow}")
    print(f"Total unaccounted contribution {total_unaccounted_cashflow}")


if __name__ == "__main__":
    main()
