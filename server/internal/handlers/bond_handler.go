package handlers

import (
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/kysakhin/temp-api/internal/repository"
)

// BondHandler holds dependencies for bond-related endpoints.
type BondHandler struct {
	repo repository.BondRepository
}

// NewBondHandler constructs a BondHandler.
func NewBondHandler(repo repository.BondRepository) *BondHandler {
	return &BondHandler{repo: repo}
}

// GetBonds handles GET /api/v1/bond
// Returns all bonds. No pagination.
// Query params: sortBy (isin|bondYield|minInvestment|tenure|rating), sortOrder (asc|desc)
func (h *BondHandler) GetBonds(c *gin.Context) {
	sortBy := strings.TrimSpace(c.Query("sortBy"))
	sortOrder := strings.TrimSpace(c.Query("sortOrder"))

	params := repository.BondQueryParams{
		SortBy:    sortBy,
		SortOrder: sortOrder,
	}

	bonds, err := h.repo.ListBonds(params)
	if err != nil {
		errInternal(c)
		return
	}

	data := make([]BondDto, len(bonds))
	for i, b := range bonds {
		data[i] = toBondDto(b)
	}

	respondOK(c, data)
}

// SearchBonds handles GET /api/v1/bond/search
// Returns bonds matching the search query. No pagination.
// Query params: q
func (h *BondHandler) SearchBonds(c *gin.Context) {
	query := strings.TrimSpace(c.Query("q"))
	if query == "" {
		respondOK(c, []BondDto{})
		return
	}

	bonds, err := h.repo.SearchBonds(query)
	if err != nil {
		errInternal(c)
		return
	}

	data := make([]BondDto, len(bonds))
	for i, b := range bonds {
		data[i] = toBondDto(b)
	}

	respondOK(c, data)
}
