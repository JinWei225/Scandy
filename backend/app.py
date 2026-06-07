import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename
from main import (get_all_transactions, delete_transaction_by_id, create_manual_transaction, create_transfer_transactions, get_all_budgets, save_budget_for_month, update_transaction_by_id, extract_data_from_image, CATEGORIES, get_all_subscriptions, save_subscription, delete_subscription, check_and_record_subscriptions, get_all_accounts, save_account, delete_account, get_account_balances)

app = Flask(__name__)
CORS(app)

UPLOAD_FOLDER = 'img'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# @app.route('/favicon.ico')
# def favicon():
#     return '', 204

@app.route('/api/transactions', methods=['GET'])
def list_transactions():
    # Endpoint to get all transactions
    transactions = get_all_transactions()
    return jsonify(transactions)

@app.route('/api/upload', methods=['POST'])
def upload_file():
    # This endpoint now only SCANS the receipt and returns the data.
    # It DOES NOT save the transaction.
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
        
    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)
        
        try:
            # Call our new OCR-only function
            print(f"OCR Started: {filename}")
            extracted_data = extract_data_from_image(filepath)
            print("OCR Success")
            
            if 'error' in extracted_data:
                print("OCR returned error:", extracted_data['error'])
                return jsonify(extracted_data), 500
                
            # Send the raw extracted data back to the frontend for confirmation.
            return jsonify(extracted_data), 200
        except Exception as e:
            import traceback
            traceback.print_exc()
            return jsonify({'error': str(e)}), 500
        finally:
            # Clean up the image after extraction, regardless of success or failure
            if os.path.exists(filepath):
                os.remove(filepath)
    
    return jsonify({'error': 'File type not allowed'}), 400
    
@app.route('/api/transactions/<transaction_id>', methods=['PUT'])
def update_transaction_route(transaction_id):
    """Endpoint to update an existing transaction."""
    data = request.get_json()
    
    try:
        updated_transaction = update_transaction_by_id(transaction_id, data)
        
        if updated_transaction:
            return jsonify(updated_transaction), 200
        else:
            return jsonify({"error": "Transaction not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 400

@app.route('/api/transactions/<transaction_id>', methods=['DELETE'])
def delete_transaction(transaction_id):
    success = delete_transaction_by_id(transaction_id)
    if success:
        return jsonify({"message": "Transaction deleted successfully"}), 200
    else:
        return jsonify({"error": "Transaction not found"}), 404
    
@app.route('/api/transactions/manual', methods=['POST'])
def add_manual_transaction_route():
    data = request.get_json()
    
    if not data or not all(k in data for k in ['date', 'description', 'amount']):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        created_record = create_manual_transaction(data)
        return jsonify(created_record), 201
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route('/api/transactions/transfer', methods=['POST'])
def add_transfer_transaction_route():
    data = request.get_json()
    
    if not data or not all(k in data for k in ['date', 'amount', 'from_account_id', 'to_account_id']):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        created_records = create_transfer_transactions(data)
        return jsonify(created_records), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    
# Endpoint to GET the budget for a specific month
@app.route('/api/budget/<year>/<month>', methods=['GET'])
def get_budget_route(year, month):
    budgets = get_all_budgets()
    budget_key = f"{year}-{int(month):02d}"
    
    budget_amount = budgets.get(budget_key)
    
    if budget_amount is not None:
        return jsonify({"amount": budget_amount})
    else:
        # It's not an error to not have a budget, so return a specific response
        return jsonify({"message": "No budget set for this month"}), 404

# Endpoint to POST (set or update) a budget for a month
@app.route('/api/budget', methods=['POST'])
def set_budget_route():
    data = request.get_json()
    year = data.get('year')
    month = data.get('month')
    amount = data.get('amount')
    
    if not all([year, month, amount]):
        return jsonify({"error": "Missing year, month, or amount"}), 400
        
    saved_budget = save_budget_for_month(year, month, amount)
    return jsonify(saved_budget), 201

@app.route('/api/categories', methods=['GET'])
def get_categories():
    """Endpoint to get the list of available transaction categories."""
    return jsonify(CATEGORIES)

@app.route('/api/subscriptions', methods=['GET'])
def list_subscriptions():
    return jsonify(get_all_subscriptions())

@app.route('/api/subscriptions', methods=['POST'])
def add_subscription():
    data = request.get_json()
    if not data or 'name' not in data or 'amount' not in data:
        return jsonify({"error": "Missing required fields"}), 400
    
    saved = save_subscription(data)
    return jsonify(saved), 201

@app.route('/api/subscriptions/<sub_id>', methods=['PUT'])
def update_subscription(sub_id):
    data = request.get_json()
    data['id'] = sub_id
    saved = save_subscription(data)
    return jsonify(saved), 200

@app.route('/api/subscriptions/<sub_id>', methods=['DELETE'])
def remove_subscription(sub_id):
    success = delete_subscription(sub_id)
    if success:
        return jsonify({"message": "Subscription deleted"}), 200
    else:
        return jsonify({"error": "Subscription not found"}), 404

@app.route('/api/subscriptions/check', methods=['POST'])
def check_subscriptions():
    created = check_and_record_subscriptions()
    return jsonify({"created": created}), 200

@app.route('/api/accounts', methods=['GET'])
def list_accounts():
    accounts = get_all_accounts()
    balances = get_account_balances()
    # Merge balances into accounts
    for acc in accounts:
        acc['balance'] = balances.get(acc['id'], 0)
    return jsonify(accounts)

@app.route('/api/accounts', methods=['POST'])
def add_account():
    data = request.get_json()
    if not data or 'name' not in data:
        return jsonify({"error": "Missing required fields"}), 400
    
    saved = save_account(data)
    return jsonify(saved), 201

@app.route('/api/accounts/<acc_id>', methods=['PUT'])
def update_account(acc_id):
    data = request.get_json()
    data['id'] = acc_id
    saved = save_account(data)
    return jsonify(saved), 200

@app.route('/api/accounts/<acc_id>', methods=['DELETE'])
def remove_account(acc_id):
    success = delete_account(acc_id)
    if success:
        return jsonify({"message": "Account deleted"}), 200
    else:
        return jsonify({"error": "Account not found"}), 404

@app.route('/api/logs', methods=['POST'])
def remote_logs():
    data = request.get_json()
    level = data.get('level', 'INFO').upper()
    message = data.get('message', '')
    context = data.get('context', '')
    print(f"[REMOTE {level}] {context}: {message}")
    return jsonify({"status": "ok"}), 200

if __name__ == '__main__':
    if not os.path.exists(UPLOAD_FOLDER):
        os.makedirs(UPLOAD_FOLDER)
    print("Flask app is ready to be served by a WSGI server like Waitress.")
    app.run(host='0.0.0.0', port=5001, debug=False, use_reloader=False)