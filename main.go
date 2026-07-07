package main

import (
	"fmt"
	"net/http"
)

func main() {

	http.HandleFunc("/bond", GetBonds)

	http.HandleFunc("/wishlist", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			GetWishlists(w, r)
		case http.MethodPost:
			CreateWishlist(w, r)
		default:
			http.NotFound(w, r)
		}
	})

	http.HandleFunc("/wishlist/", GetWishlistByID)

	fmt.Println("Listening on :8080")
	http.ListenAndServe(":8080", nil)
}
