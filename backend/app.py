import os
import traceback
import uuid
from flask import Flask, request, jsonify
from flask_cors import CORS
from ocr import OCRBusyError, OCRUnavailableError
from main import (get_all_transactions, delete_transaction_by_id, create_manual_transaction, create_transfer_transactions, update_transaction_by_id, extract_data_from_image, get_all_categories, add_category, rename_category, delete_category, get_all_subscriptions, save_subscription, delete_subscription, check_and_record_subscriptions, get_all_accounts, save_account, delete_account, get_account_balances)

app = Flask(__name__)
CORS(app)

# Absolute path so uploads land next to this file regardless of the CWD the server was started from.
# SCANDY_DATA_DIR redirects it (Docker points this at a mounted volume); unset keeps the original location.
UPLOAD_FOLDER = os.path.join(
    os.environ.get('SCANDY_DATA_DIR') or os.path.dirname(os.path.abspath(__file__)),
    'img',
)
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

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
        # Random server-side name: avoids collisions between concurrent uploads
        # and problems with filenames secure_filename() would reduce to ''.
        ext = file.filename.rsplit('.', 1)[1].lower()
        filename = f"{uuid.uuid4().hex}.{ext}"
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
        except OCRBusyError as e:
            return jsonify({'error': str(e)}), 429
        except OCRUnavailableError as e:
            # Setup problem (Ollama down, model not pulled) rather than a bad
            # image — the message tells the user how to fix it.
            return jsonify({'error': str(e)}), 503
        except Exception:
            traceback.print_exc()
            return jsonify({'error': 'Failed to process the image'}), 500
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
    except (ValueError, TypeError) as e:
        return jsonify({"error": str(e) or "Invalid transaction data"}), 400
    except Exception:
        traceback.print_exc()
        return jsonify({"error": "Failed to update transaction"}), 500

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
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid amount"}), 400
    except Exception:
        traceback.print_exc()
        return jsonify({"error": "Failed to create transaction"}), 500

@app.route('/api/transactions/transfer', methods=['POST'])
def add_transfer_transaction_route():
    data = request.get_json()
    
    if not data or not all(k in data for k in ['date', 'amount', 'from_account_id', 'to_account_id']):
        return jsonify({"error": "Missing required fields"}), 400
        
    try:
        created_records = create_transfer_transactions(data)
        return jsonify(created_records), 201
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid amount"}), 400
    except Exception:
        traceback.print_exc()
        return jsonify({"error": "Failed to create transfer"}), 500

@app.route('/api/categories', methods=['GET'])
def get_categories():
    """Endpoint to get the list of available transaction categories."""
    return jsonify(get_all_categories())

@app.route('/api/categories', methods=['POST'])
def add_category_route():
    data = request.get_json(silent=True) or {}
    try:
        categories = add_category(data.get('type'), data.get('name'))
        return jsonify(categories), 201
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception:
        traceback.print_exc()
        return jsonify({"error": "Failed to add category"}), 500

@app.route('/api/categories', methods=['PUT'])
def rename_category_route():
    data = request.get_json(silent=True) or {}
    try:
        categories = rename_category(data.get('type'), data.get('old_name'), data.get('new_name'))
        return jsonify(categories), 200
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception:
        traceback.print_exc()
        return jsonify({"error": "Failed to rename category"}), 500

@app.route('/api/categories', methods=['DELETE'])
def delete_category_route():
    data = request.get_json(silent=True) or {}
    try:
        categories = delete_category(data.get('type'), data.get('name'))
        return jsonify(categories), 200
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception:
        traceback.print_exc()
        return jsonify({"error": "Failed to delete category"}), 500

@app.route('/api/subscriptions', methods=['GET'])
def list_subscriptions():
    return jsonify(get_all_subscriptions())

def _validate_subscription(data):
    """Returns an error message, or None if the payload is valid. A bad amount stored here would 500 the startup subscription check for every client."""
    if not data or not data.get('name') or 'amount' not in data:
        return "Missing required fields"
    try:
        float(data['amount'])
    except (ValueError, TypeError):
        return "Amount must be a number"
    try:
        day = int(data.get('day_of_month', 1))
        if not 1 <= day <= 31:
            return "Day of month must be between 1 and 31"
    except (ValueError, TypeError):
        return "Day of month must be a number"
    return None

@app.route('/api/subscriptions', methods=['POST'])
def add_subscription():
    data = request.get_json()
    error = _validate_subscription(data)
    if error:
        return jsonify({"error": error}), 400

    saved = save_subscription(data)
    return jsonify(saved), 201

@app.route('/api/subscriptions/<sub_id>', methods=['PUT'])
def update_subscription(sub_id):
    data = request.get_json()
    error = _validate_subscription(data)
    if error:
        return jsonify({"error": error}), 400
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
    data = request.get_json(silent=True) or {}
    # Unauthenticated sink: cap sizes and whitelist the level so it can't be
    # used to flood the terminal or inject control sequences.
    level = str(data.get('level', 'info')).lower()
    if level not in ('info', 'warn', 'error'):
        level = 'info'
    message = str(data.get('message', ''))[:2000].replace('\x1b', '')
    context = str(data.get('context', ''))[:100].replace('\x1b', '')
    print(f"[REMOTE {level.upper()}] {context}: {message}")
    return jsonify({"status": "ok"}), 200

if __name__ == '__main__':
    print("Flask app is ready to be served by a WSGI server like Waitress.")
    app.run(host='0.0.0.0', port=5001, debug=False, use_reloader=False)