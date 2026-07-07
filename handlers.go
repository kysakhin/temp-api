package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"
)

func GetBonds(w http.ResponseWriter, r *http.Request) {
	limit := 2

	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil {
			limit = parsed
		}
	}

	cursor := r.URL.Query().Get("cursor")

	start := 0

	if cursor != "" {
		for i, b := range bonds {
			if b.ISIN == cursor {
				start = i + 1
				break
			}
		}
	}

	end := start + limit
	if end > len(bonds) {
		end = len(bonds)
	}

	json.NewEncoder(w).Encode(bonds[start:end])
}

func GetWishlists(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(wishlists)
}

func GetWishlistByID(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/wishlist/")

	var result []Bond

	for _, wb := range wishlistBonds {
		if wb.WishlistID != id {
			continue
		}

		for _, b := range bonds {
			if b.ISIN == wb.BondISIN {
				result = append(result, b)
			}
		}
	}

	json.NewEncoder(w).Encode(result)
}

type CreateWishlistRequest struct {
	Name string `json:"name"`
}

func CreateWishlist(w http.ResponseWriter, r *http.Request) {
	var req CreateWishlistRequest

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	wl := Wishlist{
		ID:        fmt.Sprintf("wl%d", len(wishlists)+1),
		UserID:    "user1",
		Name:      req.Name,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	wishlists = append(wishlists, wl)

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(wl)
}
