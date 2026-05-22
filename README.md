# 🧾 Scandy

Scandy is a sleek, modern, full-stack receipt scanner and personal transaction manager. Built to be local-first, it leverages local Vision-Language Models (VLM) via **MLX-VLM** or **Ollama** to analyze receipt images, extract transaction details, and automatically categorize them. 

The application features a beautifully responsive glassmorphism Vue.js dashboard to manage transactions, track budgets, visualize category-wise expenses, manage recurring subscriptions, and monitor account balances.

---

## ✨ Features

- **Local AI OCR Receipt Scanning:** Upload receipt images (`.jpg`, `.png`, etc.) to automatically extract:
  - Merchant Name
  - Transaction Date & Time
  - Line Items & Prices
  - Tax & Total Amount
  - Suggested Expense Category
- **Manual Transaction Logging:** Quickly log expenses with custom details, accounts, and types (expense vs. income).
- **Interactive Budgeting:** Set and monitor monthly budgets with progress tracking.
- **Expense Visualizations:** Dynamic category-wise breakdowns using **Chart.js** to understand spending patterns.
- **Subscription Tracker:** Track active, recurring subscriptions with monthly cost summaries.
- **Multi-Account Balance Management:** Monitor balances across multiple accounts (e.g., Cash, Credit Cards, Bank Accounts).
- **Capacitor Mobile Wrapper:** Full mobile responsiveness with built-in Android configuration for running as a native mobile app.

---

## 🛠️ Technology Stack

### Backend
- **Python / Flask:** Web API server
- **MLX-VLM / Ollama:** Local Vision-Language Model execution (no remote API keys required!)
- **SQLite:** Local-first relational database storage
- **Waitress:** Production-ready multi-threaded WSGI server
- **Pillow:** Image preprocessing

### Frontend
- **Vue.js:** Reactive single-page application framework
- **Chart.js & Vue-Chartjs:** Dynamic financial charts and visualizations
- **Capacitor:** Cross-platform native wrapper (runs on Web, Android, etc.)
- **Vanilla CSS:** Sleek glassmorphism and modern dark-mode responsive design

---

## 🚀 Setup & Installation

Follow these steps to run the complete stack locally.

### Prerequisites
- **Python 3.13+**
- **Node.js 18+** & **npm**
- **Ollama** installed locally (if using Ollama for receipt extraction)

---

### 1. Backend Setup

The backend dependencies can be installed using standard `pip` or using `uv` (recommended).

```bash
# Navigate to backend directory
cd backend

# Install dependencies
pip install -r requirements.txt
```

#### Running the Backend

##### Option A: Production Server with Waitress (Recommended)
Waitress is a production-ready WSGI server that is multi-threaded, highly performant, and stable.
```bash
python run_waitress.py
```

##### Option B: Development Server with Flask
Use this only for local debugging (features auto-reload):
```bash
python app.py
```

- **Port:** `5001`
- **Base URL:** `http://localhost:5001`
- **API Endpoints:** `http://localhost:5001/api/`

---

### 2. Frontend Setup

```bash
# Navigate to frontend directory
cd frontend

# Install Node dependencies
npm install
```

#### Running the Frontend

##### Compiles and Hot-Reloads for Development
```bash
npm run serve
```
The application will be accessible in your browser at `http://localhost:8080`.

##### Compiles and Minifies for Production
```bash
npm run build
```

##### Lints and Fixes Files
```bash
npm run lint
```

---

## 🔌 API Endpoints Reference

### Transactions
- `GET /api/transactions` - Retrieve all transactions
- `POST /api/transactions/manual` - Add a manual transaction
- `PUT /api/transactions/<id>` - Update an existing transaction
- `DELETE /api/transactions/<id>` - Delete a transaction
- `POST /api/upload` - Upload a receipt image and process it via local VLM

### Accounts
- `GET /api/accounts` - Retrieve all accounts and balances
- `POST /api/accounts` - Create a new account
- `PUT /api/accounts/<id>` - Update account details
- `DELETE /api/accounts/<id>` - Delete an account

### Subscriptions
- `GET /api/subscriptions` - Retrieve all active subscriptions
- `POST /api/subscriptions` - Add a recurring subscription
- `PUT /api/subscriptions/<id>` - Update subscription details
- `DELETE /api/subscriptions/<id>` - Delete a subscription

### Budgeting
- `GET /api/budget/<year>/<month>` - Get budget details for a specific month
- `POST /api/budget` - Create or update a monthly budget limit
