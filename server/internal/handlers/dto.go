package handlers

import (
	"time"

	"github.com/kysakhin/temp-api/internal/db/models"
	"github.com/shopspring/decimal"
)

// ─── Bond ────────────────────────────────────────────────────────────────────

// BondDto is the API representation of a bond.
type BondDto struct {
	ISIN            string           `json:"isin"`
	BondName        string           `json:"bondName"`
	Rating          *string          `json:"rating"`
	BondYield       *decimal.Decimal `json:"bondYield"`
	MinInvestment   *int64           `json:"minInvestment"`
	PayoutFrequency *string          `json:"payoutFrequency"`
	LogoURL         *string          `json:"logoUrl"`
	DetailURL       *string          `json:"detailUrl"`
	Tenure          decimal.Decimal  `json:"tenure"`
	MaturityDate    *string          `json:"maturityDate"` // ISO-8601 date string "YYYY-MM-DD"
	Color           *string          `json:"color"`
}

// toBondDto converts a models.Bond to a BondDto.
func toBondDto(b models.Bond) BondDto {
	var maturityDate *string
	if b.MaturityDate != nil {
		s := b.MaturityDate.Format("2006-01-02")
		maturityDate = &s
	}
	return BondDto{
		ISIN:            b.ISIN,
		BondName:        b.BondName,
		Rating:          b.Rating,
		BondYield:       b.BondYield,
		MinInvestment:   b.MinInvestment,
		PayoutFrequency: b.PayoutFrequency,
		LogoURL:         b.LogoURL,
		DetailURL:       b.DetailURL,
		Tenure:          b.Tenure,
		MaturityDate:    maturityDate,
		Color:           b.Color,
	}
}

// CursorPage is the paginated response envelope.
type CursorPage[T any] struct {
	Data       []T     `json:"data"`
	NextCursor *string `json:"nextCursor"`
	HasNext    bool    `json:"hasNext"`
}

// ─── Wishlist ─────────────────────────────────────────────────────────────────

// WishlistDto is the summary representation of a wishlist (no bonds).
type WishlistDto struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	BondCount int    `json:"bondCount"`
	CreatedAt string `json:"createdAt"`
	UpdatedAt string `json:"updatedAt"`
}

// WishlistDetailsDto is the full representation including bonds.
type WishlistDetailsDto struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	BondCount int       `json:"bondCount"`
	CreatedAt string    `json:"createdAt"`
	UpdatedAt string    `json:"updatedAt"`
	Bonds     []BondDto `json:"bonds"`
}

// formatTime converts a time.Time to an ISO-8601 UTC string.
func formatTime(t time.Time) string {
	return t.UTC().Format(time.RFC3339)
}

// ─── Requests ────────────────────────────────────────────────────────────────

// CreateWishlistRequest is the body for POST /wishlist.
type CreateWishlistRequest struct {
	Name string `json:"name" binding:"required"`
}

// UpdateWishlistRequest is the body for PATCH /wishlist/:wishlistId.
type UpdateWishlistRequest struct {
	Name string `json:"name" binding:"required"`
}

// AddBondRequest is the body for POST /wishlist/:wishlistId/bond.
type AddBondRequest struct {
	BondISIN string `json:"bondIsin" binding:"required"`
}

// UpdateBondColorRequest is the body for PATCH /bond/:isin/color.
type UpdateBondColorRequest struct {
	Color *string `json:"color"`
}
