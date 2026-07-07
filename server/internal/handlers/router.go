package handlers

import (
	"github.com/gin-gonic/gin"
	"github.com/kysakhin/temp-api/internal/repository"
)

// NewRouter wires up the Gin engine with all routes and middleware.
func NewRouter(
	bondRepo repository.BondRepository,
	wishlistRepo repository.WishlistRepository,
) *gin.Engine {
	r := gin.New()

	// Global middleware.
	r.Use(gin.Recovery()) // recover from panics, return 500
	r.Use(gin.Logger())   // structured request logging

	// All responses are JSON.
	r.Use(func(c *gin.Context) {
		c.Header("Content-Type", "application/json")
		c.Next()
	})

	bondHandler := NewBondHandler(bondRepo)
	wishlistHandler := NewWishlistHandler(wishlistRepo, bondRepo)

	v1 := r.Group("/api/v1")
	{
		// ── Bond routes ──────────────────────────────────────────────────────
		bonds := v1.Group("/bond")
		{
			bonds.GET("", bondHandler.GetBonds)
		}

		// ── Wishlist routes ───────────────────────────────────────────────────
		wishlists := v1.Group("/wishlist")
		{
			wishlists.GET("", wishlistHandler.GetWishlists)
			wishlists.POST("", wishlistHandler.CreateWishlist)

			wishlists.GET("/:wishlistId", wishlistHandler.GetWishlist)
			wishlists.PATCH("/:wishlistId", wishlistHandler.UpdateWishlist)
			wishlists.DELETE("/:wishlistId", wishlistHandler.DeleteWishlist)

			// Bond membership
			wishlists.POST("/:wishlistId/bond", wishlistHandler.AddBond)
			wishlists.DELETE("/:wishlistId/bond/:bondIsin", wishlistHandler.RemoveBond)

			// Per-bond wishlist metadata
			wishlists.PATCH("/:wishlistId/bond/:bondIsin/color", wishlistHandler.UpdateBondColor)
			wishlists.PATCH("/:wishlistId/bond/:bondIsin/position", wishlistHandler.UpdateBondPosition)

			// Bulk reorder (drag-drop)
			wishlists.PATCH("/:wishlistId/reorder", wishlistHandler.ReorderBonds)
		}
	}

	// 404 handler for unmatched routes.
	r.NoRoute(func(c *gin.Context) {
		respondError(c, 404, "NOT_FOUND", "Requested resource was not found.")
	})

	return r
}
