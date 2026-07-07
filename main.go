package main

import (
	"fmt"
	"net/http"
	"os"
)

func main() {

	http.HandleFunc("/bond", GetBonds)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

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

	fmt.Printf("Listening on :%s\n", port)
	http.ListenAndServe(":"+port, nil)
}
