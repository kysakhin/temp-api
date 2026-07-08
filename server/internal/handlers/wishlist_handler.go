package handlers

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/kysakhin/temp-api/internal/repository"
	"gorm.io/gorm"
)

const (
	maxWishlists = 5
	maxBonds     = 10
)

// WishlistHandler holds dependencies for wishlist-related endpoints.
type WishlistHandler struct {
	wishlistRepo repository.WishlistRepository
	bondRepo     repository.BondRepository
}

// NewWishlistHandler constructs a WishlistHandler.
func NewWishlistHandler(
	wishlistRepo repository.WishlistRepository,
	bondRepo repository.BondRepository,
) *WishlistHandler {
	return &WishlistHandler{
		wishlistRepo: wishlistRepo,
		bondRepo:     bondRepo,
	}
}

// ─── GET /api/v1/wishlist ────────────────────────────────────────────────────

// GetWishlists returns all wishlists (newest first) with their bond counts.
func (h *WishlistHandler) GetWishlists(c *gin.Context) {
	wishlists, err := h.wishlistRepo.ListWishlists()
	if err != nil {
		errInternal(c)
		return
	}

	dtos := make([]WishlistDto, len(wishlists))
	for i, wl := range wishlists {
		count, err := h.wishlistRepo.CountBondsInWishlist(wl.ID)
		if err != nil {
			errInternal(c)
			return
		}
		dtos[i] = WishlistDto{
			ID:        wl.ID.String(),
			Name:      wl.Name,
			BondCount: int(count),
			CreatedAt: formatTime(wl.CreatedAt),
			UpdatedAt: formatTime(wl.UpdatedAt),
		}
	}

	respondOK(c, dtos)
}

// ─── GET /api/v1/wishlist/:wishlistId ────────────────────────────────────────

// GetWishlist returns a single wishlist with all its bonds.
// Query param: sortBy — manual (default) | addedRecently | color | yield | minInvestment | tenure | rating
func (h *WishlistHandler) GetWishlist(c *gin.Context) {
	id, ok := parseUUID(c, c.Param("wishlistId"))
	if !ok {
		return
	}

	sortBy := parseWishlistSortBy(c.Query("sortBy"))

	result, err := h.wishlistRepo.GetWishlistWithBonds(id, sortBy)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			errNotFound(c)
			return
		}
		errInternal(c)
		return
	}

	bondDtos := make([]WishlistBondDto, len(result.Bonds))
	for i, entry := range result.Bonds {
		var maturityDate *string
		if entry.Bond.MaturityDate != nil {
			s := entry.Bond.MaturityDate.Format("2006-01-02")
			maturityDate = &s
		}
		bondDtos[i] = WishlistBondDto{
			ISIN:            entry.ISIN,
			BondName:        entry.BondName,
			Rating:          entry.Rating,
			BondYield:       entry.BondYield,
			MinInvestment:   entry.MinInvestment,
			PayoutFrequency: entry.PayoutFrequency,
			LogoURL:         entry.LogoURL,
			DetailURL:       entry.DetailURL,
			Tenure:          entry.Tenure,
			MaturityDate:    maturityDate,
			Color:           entry.Color,
			Position:        entry.Position,
			IsPinned:        entry.IsPinned,
		}
	}

	respondOK(c, WishlistDetailsDto{
		ID:        result.ID.String(),
		Name:      result.Name,
		BondCount: len(bondDtos),
		CreatedAt: formatTime(result.CreatedAt),
		UpdatedAt: formatTime(result.UpdatedAt),
		Bonds:     bondDtos,
	})
}

// ─── POST /api/v1/wishlist ───────────────────────────────────────────────────

// CreateWishlist creates a new wishlist.
func (h *WishlistHandler) CreateWishlist(c *gin.Context) {
	var req CreateWishlistRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errBadRequest(c, "name is required.")
		return
	}

	if err := validateWishlistName(c, req.Name); err != nil {
		return
	}

	exists, err := h.wishlistRepo.WishlistExistsByName(req.Name, uuid.Nil)
	if err != nil {
		errInternal(c)
		return
	}
	if exists {
		c.JSON(http.StatusConflict, apiError{
			Code:    "WISHLIST_ALREADY_EXISTS",
			Message: "A wishlist with this name already exists.",
		})
		return
	}

	count, err := h.wishlistRepo.CountWishlists()
	if err != nil {
		errInternal(c)
		return
	}
	if count >= maxWishlists {
		c.JSON(http.StatusUnprocessableEntity, apiError{
			Code:    "WISHLIST_LIMIT_REACHED",
			Message: "Maximum of 5 wishlists allowed.",
		})
		return
	}

	wl, err := h.wishlistRepo.CreateWishlist(req.Name)
	if err != nil {
		errInternal(c)
		return
	}

	respondCreated(c, WishlistDto{
		ID:        wl.ID.String(),
		Name:      wl.Name,
		BondCount: 0,
		CreatedAt: formatTime(wl.CreatedAt),
		UpdatedAt: formatTime(wl.UpdatedAt),
	})
}

// ─── PATCH /api/v1/wishlist/:wishlistId ─────────────────────────────────────

// UpdateWishlist renames a wishlist.
func (h *WishlistHandler) UpdateWishlist(c *gin.Context) {
	id, ok := parseUUID(c, c.Param("wishlistId"))
	if !ok {
		return
	}

	var req UpdateWishlistRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errBadRequest(c, "name is required.")
		return
	}

	if err := validateWishlistName(c, req.Name); err != nil {
		return
	}

	exists, err := h.wishlistRepo.WishlistExistsByName(req.Name, id)
	if err != nil {
		errInternal(c)
		return
	}
	if exists {
		c.JSON(http.StatusConflict, apiError{
			Code:    "WISHLIST_ALREADY_EXISTS",
			Message: "A wishlist with this name already exists.",
		})
		return
	}

	wl, err := h.wishlistRepo.UpdateWishlistName(id, req.Name)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			errNotFound(c)
			return
		}
		errInternal(c)
		return
	}

	count, err := h.wishlistRepo.CountBondsInWishlist(id)
	if err != nil {
		errInternal(c)
		return
	}

	respondOK(c, WishlistDto{
		ID:        wl.ID.String(),
		Name:      wl.Name,
		BondCount: int(count),
		CreatedAt: formatTime(wl.CreatedAt),
		UpdatedAt: formatTime(wl.UpdatedAt),
	})
}

// ─── DELETE /api/v1/wishlist/:wishlistId ────────────────────────────────────

// DeleteWishlist deletes a wishlist and all its bonds.
func (h *WishlistHandler) DeleteWishlist(c *gin.Context) {
	id, ok := parseUUID(c, c.Param("wishlistId"))
	if !ok {
		return
	}

	if err := h.wishlistRepo.DeleteWishlist(id); err != nil {
		if err == gorm.ErrRecordNotFound {
			errNotFound(c)
			return
		}
		errInternal(c)
		return
	}

	respondNoContent(c)
}

// ─── POST /api/v1/wishlist/:wishlistId/bond ──────────────────────────────────

// AddBond adds a bond to a wishlist.
func (h *WishlistHandler) AddBond(c *gin.Context) {
	wishlistID, ok := parseUUID(c, c.Param("wishlistId"))
	if !ok {
		return
	}

	var req AddBondRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errBadRequest(c, "bondIsin is required.")
		return
	}

	// Wishlist must exist.
	if _, err := h.wishlistRepo.GetWishlistByID(wishlistID); err != nil {
		if err == gorm.ErrRecordNotFound {
			errNotFound(c)
			return
		}
		errInternal(c)
		return
	}

	// Bond must exist in the catalogue.
	if _, err := h.bondRepo.GetBondByISIN(req.BondISIN); err != nil {
		if err == gorm.ErrRecordNotFound {
			errNotFound(c)
			return
		}
		errInternal(c)
		return
	}

	// Bond must not already be in this wishlist.
	exists, err := h.wishlistRepo.BondExistsInWishlist(wishlistID, req.BondISIN)
	if err != nil {
		errInternal(c)
		return
	}
	if exists {
		c.JSON(http.StatusConflict, apiError{
			Code:    "BOND_ALREADY_EXISTS",
			Message: "Bond already exists in wishlist.",
		})
		return
	}

	// Wishlist must not be full.
	count, err := h.wishlistRepo.CountBondsInWishlist(wishlistID)
	if err != nil {
		errInternal(c)
		return
	}
	if count >= maxBonds {
		c.JSON(http.StatusUnprocessableEntity, apiError{
			Code:    "WISHLIST_FULL",
			Message: "Maximum of 10 bonds allowed in a wishlist.",
		})
		return
	}

	if err := h.wishlistRepo.AddBondToWishlist(wishlistID, req.BondISIN); err != nil {
		errInternal(c)
		return
	}

	c.Status(http.StatusCreated)
}

// ─── DELETE /api/v1/wishlist/:wishlistId/bond/:bondIsin ─────────────────────

// RemoveBond removes a bond from a wishlist.
func (h *WishlistHandler) RemoveBond(c *gin.Context) {
	wishlistID, ok := parseUUID(c, c.Param("wishlistId"))
	if !ok {
		return
	}

	isin := c.Param("bondIsin")

	if err := h.wishlistRepo.RemoveBondFromWishlist(wishlistID, isin); err != nil {
		if err == gorm.ErrRecordNotFound {
			errNotFound(c)
			return
		}
		errInternal(c)
		return
	}

	respondNoContent(c)
}

// ─── PATCH /api/v1/wishlist/:wishlistId/bond/:bondIsin/pin ───────────────────

// PinBond pins or unpins a bond within a wishlist.
// Pinned bonds always appear at the top regardless of the active sort mode.
func (h *WishlistHandler) PinBond(c *gin.Context) {
	wishlistID, ok := parseUUID(c, c.Param("wishlistId"))
	if !ok {
		return
	}

	isin := c.Param("bondIsin")

	var req PinWishlistBondRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errBadRequest(c, "isPinned must be a boolean.")
		return
	}

	if err := h.wishlistRepo.PinWishlistBond(wishlistID, isin, req.IsPinned); err != nil {
		if err == gorm.ErrRecordNotFound {
			errNotFound(c)
			return
		}
		errInternal(c)
		return
	}

	respondNoContent(c)
}

// ─── PATCH /api/v1/wishlist/:wishlistId/bond/:bondIsin/color ─────────────────

// UpdateBondColor sets the tag color for a bond within a specific wishlist.
func (h *WishlistHandler) UpdateBondColor(c *gin.Context) {
	wishlistID, ok := parseUUID(c, c.Param("wishlistId"))
	if !ok {
		return
	}

	isin := c.Param("bondIsin")

	var req UpdateWishlistBondColorRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errBadRequest(c, "Invalid request body.")
		return
	}

	if err := h.wishlistRepo.UpdateWishlistBondColor(wishlistID, isin, req.Color); err != nil {
		if err == gorm.ErrRecordNotFound {
			errNotFound(c)
			return
		}
		errInternal(c)
		return
	}

	respondNoContent(c)
}

// ─── PATCH /api/v1/wishlist/:wishlistId/bond/:bondIsin/position ──────────────

// UpdateBondPosition sets the manual display position for a bond in a wishlist.
func (h *WishlistHandler) UpdateBondPosition(c *gin.Context) {
	wishlistID, ok := parseUUID(c, c.Param("wishlistId"))
	if !ok {
		return
	}

	isin := c.Param("bondIsin")

	var req UpdateWishlistBondPositionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errBadRequest(c, "position must be a non-negative integer.")
		return
	}

	if err := h.wishlistRepo.UpdateWishlistBondPosition(wishlistID, isin, req.Position); err != nil {
		if err == gorm.ErrRecordNotFound {
			errNotFound(c)
			return
		}
		errInternal(c)
		return
	}

	respondNoContent(c)
}

// ─── PATCH /api/v1/wishlist/:wishlistId/reorder ──────────────────────────────

// ReorderBonds bulk-updates the position of all bonds in a wishlist.
// Flutter sends the complete ordered list after a drag-drop; the index becomes
// the new position value for each bond.
func (h *WishlistHandler) ReorderBonds(c *gin.Context) {
	wishlistID, ok := parseUUID(c, c.Param("wishlistId"))
	if !ok {
		return
	}

	var req ReorderWishlistBondsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errBadRequest(c, "bondIsins is required and must be a non-empty array.")
		return
	}

	// Validate that the number of ISINs matches the wishlist bond count.
	count, err := h.wishlistRepo.CountBondsInWishlist(wishlistID)
	if err != nil {
		errInternal(c)
		return
	}
	if int64(len(req.BondISINs)) != count {
		errBadRequest(c, fmt.Sprintf("bondIsins must contain all %d bonds in the wishlist.", count))
		return
	}

	if err := h.wishlistRepo.ReorderWishlistBonds(wishlistID, req.BondISINs); err != nil {
		if err == gorm.ErrRecordNotFound {
			errBadRequest(c, "One or more bondIsins do not exist in this wishlist.")
			return
		}
		errInternal(c)
		return
	}

	respondNoContent(c)
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

// parseUUID parses a path param as a UUID and writes a 400 if invalid.
func parseUUID(c *gin.Context, raw string) (uuid.UUID, bool) {
	id, err := uuid.Parse(raw)
	if err != nil {
		errBadRequest(c, "Invalid UUID.")
		return uuid.UUID{}, false
	}
	return id, true
}

// validateWishlistName checks length and blank constraints.
func validateWishlistName(c *gin.Context, name string) error {
	trimmed := strings.TrimSpace(name)
	if trimmed == "" {
		errBadRequest(c, "name cannot be blank.")
		return gorm.ErrInvalidValue
	}
	if len(name) > 50 {
		errBadRequest(c, "name must be 50 characters or fewer.")
		return gorm.ErrInvalidValue
	}
	return nil
}

// parseWishlistSortBy maps the raw query param to a repository sort constant.
// Defaults to manual if unrecognised.
func parseWishlistSortBy(raw string) repository.WishlistSortBy {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "addedrecently":
		return repository.WishlistSortAddedRecently
	case "color":
		return repository.WishlistSortColor
	case "yield":
		return repository.WishlistSortYield
	case "mininvestment":
		return repository.WishlistSortMinInvestment
	case "tenure":
		return repository.WishlistSortTenure
	case "rating":
		return repository.WishlistSortRating
	default: // "manual" or anything else
		return repository.WishlistSortManual
	}
}
