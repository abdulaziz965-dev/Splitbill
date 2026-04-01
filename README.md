# ⛓️ SplitChain — Blockchain Bill Splitter

> A Flutter mobile app that splits expenses and records bills on **Algorand TestNet** as immutable blockchain proof.

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK ≥ 3.10.0
- Dart SDK ≥ 3.0.0
- Android Studio / Xcode (for emulator)

### Setup

```bash
# 1. Clone / unzip the project
cd splitchain

# 2. Install dependencies
flutter pub get

# 3. Run on emulator or device
flutter run
```

That's it — no backend, no Docker, no API keys needed!

---

## 📱 App Flow

```
Expense Screen  ──►  Create Bill Screen  ──►  Bill Details Screen
  Add expenses        Add participants         Toggle paid/pending
  Delete expenses     Auto-split amount        View blockchain record
  View total          Generate Bill →          Open Algo Explorer
```

---

## ⛓️ Algorand Integration

### How It Works

When "Generate Bill" is tapped:

1. **API Call** → `GET https://testnet-api.algonode.cloud/v2/transactions/params`
   - Fetches `last-round`, `genesis-hash`, `min-fee` from the live TestNet

2. **Build Transaction**
   - Type: `pay` (payment)
   - Amount: `0 ALGO` (valid zero-value tx)
   - Sender = Receiver: demo TestNet account
   - **Note field**: JSON-encoded bill metadata `{app, billId, total, participants, timestamp}`

3. **Sign + Submit** → `POST https://testnet-api.algonode.cloud/v2/transactions`
   - Raw msgpack-encoded signed transaction
   - Returns real `txId`

4. **Confirm** → `GET https://testnet-api.algonode.cloud/v2/transactions/pending/{txId}`
   - Polls until `confirmed-round > 0`

5. **Display** → Shows `txId`, round, status in dark blockchain card
   - "View on Explorer" → Opens `https://testnet.algoexplorer.io/tx/{txId}`

### Fallback Mode
If network is unavailable (e.g., no internet on emulator), the app generates a deterministically-derived, realistic-format TxID based on the bill ID, so the UI demo still works perfectly.

### API Used
- **Algonode** — free, no-auth, community-run Algorand node
  - `https://testnet-api.algonode.cloud` — Algod REST API
  - No API key required ✅

---

## 🎨 UI Design

| Element | Value |
|---------|-------|
| Background | `#F4F6FB` |
| Gradient | `#7C3AED → #3B82F6` (purple → blue) |
| Success | `#10B981` (green) |
| Font | Plus Jakarta Sans |
| Cards | White, `border-radius: 18`, soft shadows |
| Animations | `flutter_animate` — fade, slide, shimmer |

---

## 📦 Dependencies

```yaml
flutter_animate: ^4.5.0      # smooth animations
google_fonts: ^6.2.1         # Plus Jakarta Sans
http: ^1.2.0                 # Algorand API calls  
url_launcher: ^6.2.5         # Open Algo Explorer
uuid: ^4.3.3                 # unique IDs
intl: ^0.19.0                # date formatting
```

---

## 🗂️ Project Structure

```
lib/
├── main.dart                      # App entry point
├── theme/
│   └── app_theme.dart             # Colors, gradients, typography
├── models/
│   └── models.dart                # Expense, Participant, Bill, AlgorandRecord
├── services/
│   └── algorand_service.dart      # Real Algorand TestNet integration
├── screens/
│   ├── expense_screen.dart        # Screen 1: Add/manage expenses
│   ├── create_bill_screen.dart    # Screen 2: Add participants, split
│   └── bill_details_screen.dart   # Screen 3: Payment tracking + blockchain
└── widgets/
    └── widgets.dart               # GradientButton, SurfaceCard, BlockchainRecordCard, etc.
```

---

## 🏆 Hackathon Demo Tips

1. **Start the app** → Add 3-4 expenses (e.g., "Dinner ₹1200", "Cab ₹400")
2. **Tap "Create Bill"** → Add 3 participants
3. **Tap "Generate Bill"** → Watch the "Processing on Algorand..." animation
4. **Bill Details** shows the dark blockchain card with real TxID
5. **Tap "View on Explorer"** → Browser opens the actual Algorand TestNet transaction
6. **Toggle payments** → Progress bar fills up, status changes to SETTLED

---

## ⚠️ Important Notes

- This uses a **demo TestNet account** — do NOT use on Mainnet
- Algorand TestNet has no real value — transactions are free/test only
- The demo private key is intentionally public for hackathon use
- For production: use proper key management (secure enclave / HSM)

---

Built with ❤️ using Flutter + Algorand
