# Quick Start Guide - New Features

## What's New?

### ✅ Commodities Trading Page
Access real-time prices for:
- **Energy**: Oil (WTI/Brent), Natural Gas
- **Metals**: Copper, Aluminum  
- **Agriculture**: Wheat, Corn, Cotton, Sugar, Coffee

📍 **Location**: Home screen → "Commodities" tab

### ✅ Treasuries & Bonds Page
View US Treasury data:
- **Yield Curve**: Current rates across all maturities
- **Rate History**: 90-day historical trends
- **Public Debt**: US debt tracking with charts

📍 **Location**: Home screen → "Treasuries" tab

### ✅ Clickable News Articles
Read full articles with detailed sentiment analysis:
- Full article content
- AI sentiment classification
- Confidence scores
- Beautiful sentiment-based design

📍 **Location**: Stock Details → Sentiment tab → Click any news card

## How to Use

### Viewing Commodities
1. Tap on the "Commodities" tab from the home screen
2. Select a category: Oil, Gas, Metals, or Agriculture
3. For some categories, choose a subtype (e.g., WTI vs Brent oil)
4. View the price chart and recent data table
5. Pull to refresh for updated data

### Viewing Treasuries
1. Tap on the "Treasuries" tab from the home screen
2. Choose between three tabs:
   - **Yield Curve**: See current rates
   - **Rates History**: View 90-day trends
   - **Public Debt**: Track US debt levels
3. Scroll to see detailed data tables

### Reading News Articles
1. Go to any stock's detail page
2. Tap the "Sentiment" tab
3. Tap on any news card to read the full article
4. View detailed sentiment analysis at the bottom
5. Tap back arrow to return to stock details

## UI Guide

### Colors
- 🟢 **Green**: Positive sentiment, gains, commodities charts
- 🔴 **Red**: Negative sentiment, losses, debt charts
- 🔵 **Blue**: Neutral, treasury yields
- 🟠 **Orange**: Treasury rates history
- ⚪ **Grey**: Neutral sentiment, inactive states

### Icons
- 📈 **Trending Up**: Positive sentiment
- 📉 **Trending Down**: Negative sentiment
- ➡️ **Trending Flat**: Neutral sentiment
- 📰 **Article**: News item
- 📊 **Analytics**: Analysis data
- 🔄 **Refresh**: Retry loading

## Tips

### Performance
- Data is cached temporarily to reduce API calls
- Charts may take a moment to load on first view
- Swipe between tabs without reloading data

### Troubleshooting
- **"Failed to load data"**: Check your internet connection and tap Retry
- **Empty charts**: Some historical data may not be available yet
- **Slow loading**: Commodity and treasury data comes from external APIs and may take 5-10 seconds

### Best Practices
- Check commodities in the morning for overnight price changes
- Review yield curve regularly for market health indicators
- Read full news articles for context beyond sentiment scores
- Compare commodity prices with related stock performance

## API Notes

Backend must be running and accessible at: `http://192.168.1.148:8080`

Required endpoints:
- `/commodities/*` - Commodity data
- `/treasury/*` - Treasury data  
- `/finnewsBert/*` - News sentiment (already exists)

## Support

For issues or questions:
- Check backend is running
- Verify network connectivity
- Review error messages for specific issues
- Check backend logs for API errors

---

**Enjoy the new features! 🎉**
