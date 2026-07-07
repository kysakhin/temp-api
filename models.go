package main

import "time"

type Bond struct {
	Name            string  `json:"name"`
	ISIN            string  `json:"isin"`
	Rating          string  `json:"rating"`
	Yield           float64 `json:"yield"`
	MinInvestment   int     `json:"minInvestment"`
	PayoutFrequency string  `json:"payoutFrequency"`
	URL             string  `json:"url"`
	Color           string  `json:"color"`
}

type Wishlist struct {
	ID        string    `json:"id"`
	UserID    string    `json:"userId"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

type WishlistBond struct {
	WishlistID string    `json:"wishlistId"`
	BondISIN   string    `json:"bondIsin"`
	CreatedAt  time.Time `json:"createdAt"`
	UpdatedAt  time.Time `json:"updatedAt"`
}
