package handlers

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/kysakhin/temp-api/internal/db/models"
	"github.com/kysakhin/temp-api/internal/repository"
	"gorm.io/gorm"
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
// Query params: limit (default 20), cursor, sortBy, sortOrder
func (h *BondHandler) GetBonds(c *gin.Context) {
	limit := 20
	if l := c.Query("limit"); l != "" {
		parsed, err := strconv.Atoi(l)
		if err != nil || parsed <= 0 {
			errBadRequest(c, "limit must be a positive integer.")
			return
		}
		limit = parsed
	}

	sortBy := strings.TrimSpace(c.Query("sortBy"))
	sortOrder := strings.TrimSpace(c.Query("sortOrder"))
	cursor := strings.TrimSpace(c.Query("cursor"))

	// Resolve effective sortBy / sortOrder (mirrors defaults applied in repo).
	effectiveSortBy := sortBy
	if effectiveSortBy == "" {
		effectiveSortBy = "isin"
	}
	effectiveSortOrder := strings.ToLower(sortOrder)
	if effectiveSortOrder != "asc" && effectiveSortOrder != "desc" {
		effectiveSortOrder = "asc"
	}

	params := repository.BondQueryParams{
		Limit:     limit,
		Cursor:    cursor,
		SortBy:    sortBy,
		SortOrder: sortOrder,
	}

	bonds, err := h.repo.ListBonds(params)
	if err != nil {
		errInternal(c)
		return
	}

	// Determine hasNext: we fetched limit+1 rows inside the repo.
	hasNext := len(bonds) > limit
	if hasNext {
		bonds = bonds[:limit]
	}

	// Map to DTOs.
	data := make([]BondDto, len(bonds))
	for i, b := range bonds {
		data[i] = toBondDto(b)
	}

	// Build next cursor from the last item in the trimmed slice.
	var nextCursor *string
	if hasNext && len(data) > 0 {
		last := data[len(data)-1]
		sortVal := bondSortVal(last, effectiveSortBy)
		encoded := repository.EncodeCursor(effectiveSortBy, effectiveSortOrder, sortVal, last.ISIN)
		nextCursor = &encoded
	}

	c.JSON(http.StatusOK, CursorPage[BondDto]{
		Data:       data,
		NextCursor: nextCursor,
		HasNext:    hasNext,
	})
}

// UpdateBondColor handles PATCH /api/v1/bond/:isin/color
func (h *BondHandler) UpdateBondColor(c *gin.Context) {
	isin := c.Param("isin")

	var req UpdateBondColorRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errBadRequest(c, "Invalid request body.")
		return
	}

	if err := h.repo.UpdateBondColor(isin, req.Color); err != nil {
		if err == gorm.ErrRecordNotFound {
			errNotFound(c)
			return
		}
		errInternal(c)
		return
	}

	bond, err := h.repo.GetBondByISIN(isin)
	if err != nil {
		errInternal(c)
		return
	}

	respondOK(c, toBondDto(*bond))
}

// bondSortVal returns the string to embed in a cursor for the last item's
// sort field. "null" is used when the field is nil (NULLS LAST ordering).
func bondSortVal(dto BondDto, sortBy string) string {
	switch sortBy {
	case "bondYield":
		if dto.BondYield == nil {
			return "null"
		}
		return dto.BondYield.String()
	case "minInvestment":
		if dto.MinInvestment == nil {
			return "null"
		}
		return fmt.Sprintf("%d", *dto.MinInvestment)
	case "tenure":
		return dto.Tenure.String()
	case "rating":
		if dto.Rating == nil {
			return "null"
		}
		return *dto.Rating
	default: // "isin"
		return dto.ISIN
	}
}

// ensure models import is used (Bond type is used in toBondDto, defined in dto.go)
var _ = models.Bond{}
