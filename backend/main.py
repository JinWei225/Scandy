import json
import os
import sqlite3
from datetime import datetime, date # For transactionID in future
from receipt_extractor import extract_receipt_data

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_FILE = os.path.join(BASE_DIR, "database.sqlite")
BUDGET_FILE = os.path.join(BASE_DIR, "budgets.json")
SUBSCRIPTIONS_FILE = os.path.join(BASE_DIR, "subscriptions.json")

def get_db_connection():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db_connection()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS transactions (
            id TEXT PRIMARY KEY,
            date TEXT,
            time TEXT,
            description TEXT,
            amount TEXT,
            category TEXT,
            account_id TEXT,
            type TEXT,
            transfer_related_id TEXT
        )
    """)
    conn.commit()
    conn.close()

init_db()
ACCOUNTS_FILE = os.path.join(BASE_DIR, "accounts.json")

CATEGORIES = {
    "expense": [
        "Food & Drink",
        "Shopping",
        "Transport",
        "Bills & Utilities",
        "Entertainment",
        "Health",
        "Groceries",
        "Installments",
        "Other"
    ],
    "income": [
        "Salary",
        "Investments",
        "Gifts",
        "Refunds",
        "Other"
    ],
    "transfer": ["Transfer"]
}

def json_date_converter(obj):
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError(f"Type {type(obj)} not serializable")

def extract_data_from_image(image_path):
    # Try local OCR first
    try:
        data = extract_receipt_data(image_path)
        # Check if basic fields are present (amount, date)
        if data.get("amount") and data.get("date"):
            return _clean_extracted_data(data)
    except Exception as e:
        print(f"Local OCR failed: {e}")

def _clean_extracted_data(data):
    if "error" in data:
        return data

    # Clean the amount field, but don't add other fields yet
    if data.get("amount"):
        data["amount"] = data["amount"].replace('-', '')
    
    return data

def get_all_transactions():
    try:
        conn = get_db_connection()
        rows = conn.execute("SELECT * FROM transactions").fetchall()
        conn.close()
        data = []
        for row in rows:
            d = dict(row)
            if d.get("amount") is not None:
                try:
                    amount_int = int(d["amount"])
                    d["amount"] = f"RM {amount_int / 100.0:.2f}"
                except ValueError:
                    pass
            data.append(d)
        return sort_transactions(data)
    except Exception as e:
        print(f"Error reading DB: {e}")
        return []

def sort_transactions(data):
    # Sort by date and time, newest first.
    # Date format in JSON is "DD/MM/YYYY" or "YYYY-MM-DD"
    # Time format is "HH:MM:SS" or "HH:MM"
    
    def parse_datetime(item):
        d_str = item.get("date")
        t_str = item.get("time", "00:00:00")
        
        if not d_str or not isinstance(d_str, str):
            return datetime.min
            
        # Try finding the right date parser
        dt = None
        for d_fmt in ["%d/%m/%Y", "%Y-%m-%d"]:
            try:
                dt = datetime.strptime(d_str, d_fmt)
                break
            except ValueError:
                continue
        
        if not dt:
            return datetime.min
            
        # Try finding the right time parser
        for t_fmt in ["%H:%M:%S", "%H:%M"]:
            try:
                tm = datetime.strptime(t_str, t_fmt).time()
                return datetime.combine(dt.date(), tm)
            except ValueError:
                continue
        
        # Fallback to date only if time is weird
        return dt

    # Sort
    sorted_data = sorted(data, key=parse_datetime, reverse=True)
    return sorted_data

def create_manual_transaction(data):
    amount_int = int(round(float(data.get('amount', 0)) * 100))
    new_record = {
        "id": datetime.now().isoformat(),
        "date": data.get("date"),
        "time": data.get("time", "00:00:00"),
        "description": data.get("description"),
        "amount": str(amount_int),
        "category": data.get("category", "Uncategorized"),
        "account_id": data.get("account_id"),
        "type": data.get("type", "expense"),
        "transfer_related_id": None
    }
    
    conn = get_db_connection()
    conn.execute("""
        INSERT INTO transactions (id, date, time, description, amount, category, account_id, type, transfer_related_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (new_record["id"], new_record["date"], new_record["time"], new_record["description"], new_record["amount"], new_record["category"], new_record["account_id"], new_record["type"], new_record["transfer_related_id"]))
    conn.commit()
    conn.close()
        
    # Format amount for frontend response
    new_record["amount"] = f"RM {amount_int / 100.0:.2f}"
    return new_record

def create_transfer_transactions(data):
    """Creates a pair of transactions for a transfer."""
    date_str = data.get("date")
    time_str = data.get("time", "00:00:00")
    amount = float(data.get("amount", 0))
    amount_int = int(round(amount * 100))
    from_account = data.get("from_account_id")
    to_account = data.get("to_account_id")
    timestamp = datetime.now().isoformat()
    
    # 1. Outgoing (Expense) from Source
    outgoing = {
        "id": f"{timestamp}_out",
        "date": date_str,
        "time": time_str,
        "description": f"Transfer to Account", 
        "amount": str(amount_int),
        "category": "Transfer",
        "account_id": from_account,
        "type": "expense",
        "transfer_related_id": f"{timestamp}_in" 
    }
    
    # 2. Incoming (Income) to Destination
    incoming = {
        "id": f"{timestamp}_in",
        "date": date_str,
        "time": time_str,
        "description": f"Transfer from Account",
        "amount": str(amount_int),
        "category": "Transfer",
        "account_id": to_account,
        "type": "income",
        "transfer_related_id": f"{timestamp}_out"
    }
    
    conn = get_db_connection()
    for t in [outgoing, incoming]:
        conn.execute("""
            INSERT INTO transactions (id, date, time, description, amount, category, account_id, type, transfer_related_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (t["id"], t["date"], t["time"], t["description"], t["amount"], t["category"], t["account_id"], t["type"], t["transfer_related_id"]))
    conn.commit()
    conn.close()
    
    # Format amount for frontend response
    for t in [outgoing, incoming]:
        t["amount"] = f"RM {amount_int / 100.0:.2f}"
        
    return [outgoing, incoming]

def update_transaction_by_id(transaction_id, data_to_update):
    """Finds a transaction and updates its details."""
    conn = get_db_connection()
    row = conn.execute("SELECT * FROM transactions WHERE id = ?", (transaction_id,)).fetchone()
    
    if not row:
        conn.close()
        return None # Indicate that the transaction was not found
    
    transaction_to_update = dict(row)

    # Check if transforming from regular transaction to transfer (or editing an existing transfer)
    if data_to_update.get("type") == "transfer":
        related_id = transaction_to_update.get("transfer_related_id")
        
        if not data_to_update.get("to_account_id") or not data_to_update.get("account_id"):
            conn.close()
            raise ValueError("Transfer requires both From and To accounts.")
            
        # Delete original(s)
        conn.execute("DELETE FROM transactions WHERE id = ?", (transaction_id,))
        if related_id:
            conn.execute("DELETE FROM transactions WHERE id = ?", (related_id,))
        conn.commit()
        conn.close()
        
        # Create transfer
        amount_val = data_to_update.get("amount")
        if amount_val is not None:
             amount_val = str(amount_val).replace("RM", "").strip()
        else:
             amount_val = str(int(transaction_to_update.get("amount", 0)) / 100.0)
             
        transfer_data = {
            "date": data_to_update.get("date", transaction_to_update["date"]),
            "time": data_to_update.get("time", transaction_to_update.get("time", "00:00:00")),
            "description": "Transfer",
            "amount": amount_val,
            "from_account_id": data_to_update.get("account_id"),
            "to_account_id": data_to_update.get("to_account_id")
        }
        res = create_transfer_transactions(transfer_data)
        return res[0]

    # Update the fields from the provided data
    transaction_to_update["date"] = data_to_update.get("date", transaction_to_update["date"])
    transaction_to_update["time"] = data_to_update.get("time", transaction_to_update.get("time", "00:00:00"))
    transaction_to_update["description"] = data_to_update.get("description", transaction_to_update["description"])
    
    # Handle amount update - if it's a number, format it
    if "amount" in data_to_update:
         amount_str = str(data_to_update['amount']).replace("RM", "").strip()
         transaction_to_update["amount"] = str(int(round(float(amount_str) * 100)))
         
    transaction_to_update["category"] = data_to_update.get("category", transaction_to_update["category"])
    transaction_to_update["account_id"] = data_to_update.get("account_id", transaction_to_update.get("account_id"))
    transaction_to_update["type"] = data_to_update.get("type", transaction_to_update.get("type", "expense"))

    conn.execute("""
        UPDATE transactions SET 
        date=?, time=?, description=?, amount=?, category=?, account_id=?, type=?
        WHERE id=?
    """, (
        transaction_to_update["date"],
        transaction_to_update["time"],
        transaction_to_update["description"],
        transaction_to_update["amount"],
        transaction_to_update["category"],
        transaction_to_update["account_id"],
        transaction_to_update["type"],
        transaction_to_update["id"]
    ))
    conn.commit()
    conn.close()
    
    # Format amount for frontend response
    if "amount" in transaction_to_update and transaction_to_update["amount"] is not None:
        try:
            amount_int = int(transaction_to_update["amount"])
            transaction_to_update["amount"] = f"RM {amount_int / 100.0:.2f}"
        except ValueError:
            pass
            
    return transaction_to_update

def delete_transaction_by_id(transaction_id):
    """Deletes a transaction by ID."""
    conn = get_db_connection()
    cursor = conn.execute("DELETE FROM transactions WHERE id = ?", (transaction_id,))
    deleted = cursor.rowcount > 0
    conn.commit()
    conn.close()
    return deleted

def get_all_budgets():
    try:
        with open(BUDGET_FILE, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}

def save_budget_for_month(year, month, amount):
    budgets = get_all_budgets()
    
    # Create a unique key like "2025-10"
    budget_key = f"{year}-{int(month):02d}"
    
    budgets[budget_key] = float(amount)
    
    with open(BUDGET_FILE, "w") as f:
        json.dump(budgets, f, indent=4)
        
    return {budget_key: amount}

def get_all_subscriptions():
    try:
        with open(SUBSCRIPTIONS_FILE, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return []

def save_all_subscriptions(subscriptions):
    with open(SUBSCRIPTIONS_FILE, "w") as f:
        json.dump(subscriptions, f, indent=4)

def save_subscription(data):
    subscriptions = get_all_subscriptions()
    
    # Check if 'id' is missing or empty string/null
    if "id" not in data or not data["id"]:
        data["id"] = datetime.now().isoformat()
        subscriptions.append(data)
    else:
        # Update existing
        for i, sub in enumerate(subscriptions):
            if sub["id"] == data["id"]:
                subscriptions[i] = data
                break
        else:
            # If ID provided but not found, treat as new (or append)
            subscriptions.append(data)
            
    save_all_subscriptions(subscriptions)
    return data

def delete_subscription(sub_id):
    subscriptions = get_all_subscriptions()
    initial_len = len(subscriptions)
    subscriptions = [s for s in subscriptions if s["id"] != sub_id]
    
    if len(subscriptions) < initial_len:
        save_all_subscriptions(subscriptions)
        return True
    return False

def check_and_record_subscriptions():
    subscriptions = get_all_subscriptions()
    today = datetime.now()
    current_month_str = today.strftime("%Y-%m")
    created_transactions = []
    
    updated = False
    
    for sub in subscriptions:
        # Check if already recorded for this month
        last_recorded = sub.get("last_recorded_date")
        if last_recorded and last_recorded.startswith(current_month_str):
            continue
            
        # Check if due date has passed or is today
        try:
            day_of_month = int(sub.get("day_of_month", 1))
        except ValueError:
            day_of_month = 1
            
        if today.day >= day_of_month:
            # Create transaction
            transaction_date = f"{day_of_month:02d}/{today.month:02d}/{today.year}"
            
            # If the calculated date is in the future (e.g. today is 30th, due is 31st, but current month only has 30 days),
            # we might need adjustment. For simplicity, if day > max day of month, use max day.
            # But here we are checking if today.day >= day_of_month, so the day definitely exists in this month 
            # (unless day_of_month is invalid like 32).
            
            tx_data = {
                "date": transaction_date,
                "description": f"Subscription: {sub.get('name')}",
                "amount": sub.get("amount"),
                "category": sub.get("category", "Bills & Utilities"),
                "account_id": sub.get("account_id")
            }
            
            create_manual_transaction(tx_data)
            created_transactions.append(tx_data)
            
            # Update subscription
            sub["last_recorded_date"] = today.strftime("%Y-%m-%d")
            updated = True
            
    if updated:
        save_all_subscriptions(subscriptions)
        
    return created_transactions

def get_all_accounts():
    try:
        with open(ACCOUNTS_FILE, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return []

def save_all_accounts(accounts):
    with open(ACCOUNTS_FILE, "w") as f:
        json.dump(accounts, f, indent=4)

def save_account(data):
    accounts = get_all_accounts()
    
    if "id" not in data or not data["id"]:
        data["id"] = datetime.now().isoformat()
        accounts.append(data)
    else:
        for i, acc in enumerate(accounts):
            if acc["id"] == data["id"]:
                accounts[i] = data
                break
        else:
            accounts.append(data)
            
    save_all_accounts(accounts)
    return data

def delete_account(account_id):
    accounts = get_all_accounts()
    initial_len = len(accounts)
    accounts = [a for a in accounts if a["id"] != account_id]
    
    if len(accounts) < initial_len:
        save_all_accounts(accounts)
        return True
    return False

def get_account_balances():
    accounts = get_all_accounts()
    transactions = get_all_transactions()
    
    # Initialize balances with initial_amount from account config
    balances = {}
    for acc in accounts:
        try:
            initial = float(acc.get("initial_balance", 0))
        except ValueError:
            initial = 0.0
        balances[acc["id"]] = int(round(initial * 100))
        
    # Process transactions
    for t in transactions:
        acc_id = t.get("account_id")
        if acc_id and acc_id in balances:
            try:
                # Amount string is like "RM 123.45"
                raw_amount = t.get("amount", "0")
                if raw_amount is None:
                    raw_amount = "0"
                
                amount_str = str(raw_amount).replace("RM", "").strip()
                amount = int(round(float(amount_str) * 100))
                
                # Determine if income or expense
                # Default to 'expense' if not specified
                t_type = t.get("type", "expense")
                
                if t_type == "income":
                    balances[acc_id] += amount
                else:
                    balances[acc_id] -= amount
                    
            except (ValueError, AttributeError):
                continue
                
    # Convert back to float for output
    for k in balances:
        balances[k] = balances[k] / 100.0

    return balances
