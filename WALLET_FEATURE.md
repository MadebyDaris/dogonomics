# Wallet Feature Implementation

## Overview
Implemented a comprehensive wallet system that allows users to track and manage multiple asset types including stocks, bonds, and commodities in a unified view.

## New Files Created

### 1. Wallet Data Model (`lib/utils/walletData.dart`)
**Purpose**: Defines the data structure for multi-asset wallet functionality

**Key Components**:
- `AssetType` enum: stock, bond, commodity
- `WalletAsset` abstract class: Base class for all asset types
- `StockAsset`: Extends WalletAsset for stocks (includes change tracking)
- `BondAsset`: Extends WalletAsset for treasury bonds (includes coupon rate, maturity date, face value)
- `CommodityAsset`: Extends WalletAsset for commodities (includes category, unit)
- `Wallet` class: Container for all assets with computed properties:
  - `totalValue`: Sum of all asset values
  - `stocksValue`, `bondsValue`, `commoditiesValue`: Category-specific totals
  - `stockCount`, `bondCount`, `commodityCount`: Asset counts by type
  - Methods to add/remove assets and convert to/from Firebase format

### 2. Wallet Page (`lib/pages/walletPage.dart`)
**Purpose**: Main wallet dashboard showing total portfolio across all asset types

**Features**:
- **Total Wallet Overview Card**:
  - Total wallet value with gradient design
  - Asset count breakdown (total, stocks, bonds, commodities)
  
- **Asset Allocation Pie Chart**:
  - Visual breakdown by asset type (stocks=blue, bonds=green, commodities=orange)
  - Percentage labels on chart
  - Interactive legend with values and percentages
  
- **Asset Type Summary Cards**:
  - Individual cards for stocks, bonds, and commodities
  - Shows count and total value per category
  - Icon-coded (chart for stocks, bank for bonds, eco for commodities)
  
- **Filterable Asset List**:
  - Filter chips: All, Stocks, Bonds, Commodities
  - Detailed list items showing:
    - Asset name and symbol
    - Quantity and current price/details
    - Total value
    - Change percentage (for stocks)

### 3. Add Asset Dialog (`lib/widgets/addAssetDialog.dart`)
**Purpose**: Reusable dialog for adding bonds and commodities to wallet

**Features**:
- Dynamically adapts form based on asset type
- For all assets:
  - Shows current price
  - Quantity input with validation
  - Real-time total calculation
- For bonds specifically:
  - Coupon rate input
  - Maturity date input
- Saves to Firebase Firestore (`users/{uid}/wallet.assets` array)
- Shows success/error notifications

## Modified Files

### 1. Treasuries Page (`lib/pages/treasuriesPage.dart`)
**Changes**:
- Added imports for `walletData.dart` and `addAssetDialog.dart`
- Enhanced yield curve treasury list items:
  - Added "Add" button next to each treasury security
  - Shows rate prominently
  - Button triggers `_showAddBondDialog()` method
- New method `_showAddBondDialog()`:
  - Opens add asset dialog with bond type
  - Pre-fills treasury information
  - Sets face value to standard $100
  - Shows success notification after adding

### 2. Commodities Page (`lib/pages/commoditiesPage.dart`)
**Changes**:
- Added imports for `walletData.dart` and `addAssetDialog.dart`
- Enhanced commodity header:
  - Added "Add to Wallet" button in top-right
  - Button shows current commodity name
  - Maintains responsive layout
- New method `_showAddCommodityDialog()`:
  - Opens add asset dialog with commodity type
  - Pre-fills current price, category, and unit
  - Generates symbol from selected subtype
  - Shows success notification after adding

### 3. Front Page (`lib/pages/frontpage.dart`)
**Changes**:
- Added imports for `walletPage.dart` and `walletData.dart`
- Added wallet icon button to AppBar actions:
  - Wallet icon (📱 style)
  - Tooltip: "Total Wallet"
  - Positioned before search icon
- New method `_openWallet()`:
  - Creates Wallet object from user's portfolio
  - Converts Stock objects to StockAsset instances
  - Navigates to WalletPage
  - TODO: Load bonds and commodities from Firestore

## Data Flow

### Adding Assets to Wallet:
1. User views treasury or commodity page
2. Clicks "Add" or "Add to Wallet" button
3. Dialog opens with pre-filled asset information
4. User enters quantity (and bond-specific details if applicable)
5. Dialog validates input and calculates total
6. On submit, asset is saved to Firestore:
   ```
   users/{userId}/wallet/assets (array)
   ```
7. Success notification shown

### Viewing Wallet:
1. User clicks wallet icon in AppBar
2. `_openWallet()` creates Wallet from user's portfolio
3. Currently loads only stocks from AppUser.portfolio
4. WalletPage displays:
   - Total value across all assets
   - Breakdown by asset type (pie chart)
   - Category summaries
   - Filtered list of all holdings

## Integration with Firebase

### Data Structure:
```dart
users/{userId}/
  portfolio: [Stock] // Existing stock portfolio
  wallet:
    assets: [
      {
        type: 'stock' | 'bond' | 'commodity',
        symbol: String,
        name: String,
        currentValue: double,
        quantity: double,
        // Bond-specific
        issuer: String,
        couponRate: double,
        maturityDate: String,
        faceValue: double,
        // Commodity-specific
        category: String,
        unit: String
      }
    ]
```

### Current Limitation:
The `_openWallet()` method in frontpage.dart currently only loads stocks from the existing portfolio. Bonds and commodities added through the dialog are saved to Firestore but need to be loaded when opening the wallet. This is marked with a TODO comment.

## User Experience

### Navigation Flow:
```
Home Page
├── Stocks Tab (existing)
├── Commodities Tab
│   └── Click commodity "Add to Wallet" → Dialog → Save to Firebase
├── Treasuries Tab
│   └── Click treasury "Add" → Dialog → Save to Firebase
├── CFDs Tab (coming soon)
└── Wallet Icon (AppBar)
    └── Opens Wallet Page showing all holdings
```

### Visual Design:
- **Color Coding**:
  - Stocks: Blue
  - Bonds: Green
  - Commodities: Orange
- **Dark Theme**: Consistent with existing app (STOCK_CARD, MAINGREY)
- **Interactive Elements**: Buttons, chips, tappable cards
- **Responsive Charts**: fl_chart pie charts with legends

## Next Steps

### To Complete Full Wallet Functionality:
1. **Load Wallet Data from Firestore**:
   - Modify `AppUser` model to include wallet field
   - Update `_openWallet()` to load from Firestore
   - Fetch bonds and commodities alongside portfolio

2. **Real-time Price Updates**:
   - Commodities: Call Alpha Vantage API with saved symbols
   - Bonds: Update based on current treasury rates
   - Stocks: Already handled by existing quote API

3. **Wallet Management**:
   - Remove assets from wallet
   - Edit quantities
   - Transaction history

4. **Advanced Analytics**:
   - Risk distribution across asset types
  - Rebalancing suggestions
   - Performance tracking over time

## Dependencies
- `fl_chart`: ^0.x.x (pie charts, line charts)
- `firebase_auth`: ^x.x.x (user authentication)
- `cloud_firestore`: ^x.x.x (data persistence)

## Testing Checklist
- [ ] Add bond to wallet from treasuries page
- [ ] Add commodity to wallet from commodities page
- [ ] View wallet shows all three asset types
- [ ] Pie chart displays correct percentages
- [ ] Filter chips work correctly
- [ ] Total value calculates correctly
- [ ] Navigation from AppBar wallet icon works
- [ ] Firebase saves wallet data persistently
- [ ] Loading existing wallet data on restart
