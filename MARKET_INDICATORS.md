# Market Indicators Page - Implementation

## Overview
The Market Indicators page provides real-time quotes for major market indices and ETFs, giving users a quick snapshot of overall market health.

## Features

### Market Indices Tracked
1. **SPY** - S&P 500 ETF (Blue)
   - Tracks the S&P 500 index
   - Represents large-cap US stocks

2. **QQQ** - NASDAQ-100 ETF (Green)
   - Tracks top 100 NASDAQ stocks
   - Tech-heavy index

3. **DIA** - Dow Jones ETF (Orange)
   - Tracks the Dow Jones Industrial Average
   - 30 major US companies

4. **IWM** - Russell 2000 ETF (Purple)
   - Tracks small-cap stocks
   - Indicator of small business health

5. **VIX** - Volatility Index (Red)
   - Market fear gauge
   - High VIX = High volatility/fear

### Market Overview Section
- **Up/Down/Neutral Counter**: Shows how many indices are positive, negative, or flat
- **Market Sentiment**: Displays bullish 🐂, bearish 🐻, or mixed ➡️ sentiment based on the majority
- **Visual Indicators**: Color-coded icons (trending up/down/flat)

### Individual Index Cards
Each index card displays:
- **Symbol & Name**: Easy identification
- **Current Price**: Latest trading price
- **Percentage Change**: Daily change with color coding
- **Description**: What the index tracks
- **Color-Coded Icons**: Each index has its own color theme
- **Tap to View Details**: Shows full quote information

### Interactive Features
- **Pull to Refresh**: Swipe down to update all quotes
- **Refresh Button**: Manual refresh in app bar
- **Detail Dialog**: Tap any index for comprehensive data:
  - Current Price
  - Change (dollar amount)
  - Change % (percentage)
  - Open Price
  - High of Day
  - Low of Day
  - Previous Close

## Technical Implementation

### Data Flow
1. On page load, fetches quotes for all 5 indices concurrently
2. Each quote is fetched from `/quote/:symbol` endpoint
3. Data is stored in state maps for efficient rendering
4. Loading states and errors are tracked per index

### State Management
```dart
Map<String, QuoteData?> quotes = {};    // Stores quote data
Map<String, bool> loading = {};          // Tracks loading state
Map<String, String?> errors = {};        // Stores error messages
```

### API Model
```dart
class QuoteData {
  final double currentPrice;      // Current trading price
  final double change;            // Dollar change
  final double percentChange;     // Percentage change
  final double highPrice;         // Day high
  final double lowPrice;          // Day low
  final double openPrice;         // Opening price
  final double previousClose;     // Previous close
  final int timestamp;            // Unix timestamp
}
```

### Backend Endpoint
- **Endpoint**: `GET /quote/:symbol`
- **Response Format**: JSON matching QuoteData structure
- **Timeout**: 30 seconds
- **Source**: Finnhub API (via backend)

## UI Design

### Color Scheme
- **Background**: Dark theme (`BACKG_COLOR`)
- **Cards**: Dark grey (`STOCK_CARD`)
- **Positive**: Green (gains)
- **Negative**: Red (losses)
- **Neutral**: Grey (no change)
- **Each Index**: Custom color for visual distinction

### Layout
1. **Market Overview Card** (Top)
   - Gradient background
   - Analytics icon with accent color
   - Three-column stat display
   - Market sentiment text

2. **Index Cards** (Scrollable List)
   - Icon with color-coded background
   - Symbol and name
   - Large price display
   - Percentage badge
   - Description text

3. **Detail Dialog** (On Tap)
   - Matching index color theme
   - Two-column data display
   - Label-value pairs
   - Close button

## User Experience

### Loading States
- Individual loading indicators per index
- "Loading market data..." in overview
- Smooth transitions when data arrives

### Error Handling
- Per-index error messages
- "Failed to load" displayed on cards
- Retry via refresh button or pull-to-refresh

### Interactions
- **Tap**: View detailed quote information
- **Pull Down**: Refresh all quotes
- **Refresh Button**: Manual refresh
- **Dialog**: Dismiss with button or back gesture

## Market Sentiment Logic

```dart
if (positive_count > negative_count) {
  return "🐂 Market is showing bullish sentiment";
} else if (negative_count > positive_count) {
  return "🐻 Market is showing bearish sentiment";
} else {
  return "➡️ Market is showing mixed sentiment";
}
```

## Performance Considerations

1. **Concurrent Loading**: All quotes fetched in parallel
2. **Individual Error Handling**: One failed quote doesn't block others
3. **Minimal Re-renders**: State maps prevent unnecessary rebuilds
4. **Efficient Updates**: Only changed data triggers UI updates

## Future Enhancements

Potential improvements:
- Real-time streaming updates via WebSocket
- Historical charts for each index
- Customizable index list
- Notifications for major market movements
- Sector performance breakdown
- International markets (DAX, FTSE, Nikkei)
- Comparison view between indices
- Export market snapshot
- Price alerts

## Testing Checklist

- [ ] All 5 indices load correctly
- [ ] Percentage changes display proper colors
- [ ] Market overview calculates correctly
- [ ] Detail dialog shows all fields
- [ ] Pull-to-refresh works
- [ ] Refresh button updates data
- [ ] Error states display properly
- [ ] Loading states show/hide correctly
- [ ] Tap interaction works on all cards
- [ ] Dialog dismisses properly

## Notes

- Indices are ETFs that track the actual indices (easier to get real-time data)
- VIX shows volatility level (higher = more market fear)
- Market sentiment is a simple heuristic based on majority direction
- All prices update on refresh (not real-time streaming)
- Backend must be running for data to load

## Integration

The Market Indicators page is accessible from:
- Stock view page (via navigation button)
- Can be added to home screen tabs if needed
- Direct navigation from any page

---

**Last Updated**: October 24, 2025
