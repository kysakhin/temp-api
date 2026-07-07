package main

import "time"

var bonds = []Bond{
	{
		Name:            "HDFC Bond",
		ISIN:            "IN001",
		Rating:          "AAA",
		Yield:           7.5,
		MinInvestment:   10000,
		PayoutFrequency: "Quarterly",
		URL:             "https://example.com/1",
		Color:           "#4285F4",
	},
	{
		Name:            "ICICI Bond",
		ISIN:            "IN002",
		Rating:          "AA+",
		Yield:           8.2,
		MinInvestment:   5000,
		PayoutFrequency: "Monthly",
		URL:             "https://example.com/2",
		Color:           "#DB4437",
	},
	{
		Name:            "Axis Bond",
		ISIN:            "IN003",
		Rating:          "AAA",
		Yield:           7.9,
		MinInvestment:   15000,
		PayoutFrequency: "Yearly",
		URL:             "https://example.com/3",
		Color:           "#0F9D58",
	},
}

var wishlists = []Wishlist{
	{
		ID:        "wl1",
		UserID:    "user1",
		Name:      "High Yield",
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	},
}

var wishlistBonds = []WishlistBond{
	{
		WishlistID: "wl1",
		BondISIN:   "IN001",
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	},
	{
		WishlistID: "wl1",
		BondISIN:   "IN003",
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	},
}
