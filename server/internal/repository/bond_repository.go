package repository

import (
	"fmt"
	"strings"

	"github.com/kysakhin/temp-api/internal/db/models"
	"gorm.io/gorm"
)

// BondSortField enumerates the columns by which bonds can be sorted.
type BondSortField string

const (
	SortByISIN          BondSortField = "isin"
	SortByBondYield     BondSortField = "bond_yield"
	SortByMinInvestment BondSortField = "min_investment"
	SortByTenure        BondSortField = "tenure"
	SortByRating        BondSortField = "rating"
)

// validSortFields maps the client-facing camelCase param to the DB column name.
var validSortFields = map[string]BondSortField{
	"isin":          SortByISIN,
	"bondYield":     SortByBondYield,
	"minInvestment": SortByMinInvestment,
	"tenure":        SortByTenure,
	"rating":        SortByRating,
}

// BondQueryParams carries sort parameters for listing bonds.
type BondQueryParams struct {
	SortBy    string // client param name, e.g. "bondYield"
	SortOrder string // "asc" | "desc"
}

// BondRepository defines the data-access contract for bonds.
type BondRepository interface {
	ListBonds(params BondQueryParams) ([]models.Bond, error)
	GetBondByISIN(isin string) (*models.Bond, error)
}

type bondRepository struct {
	db *gorm.DB
}

// NewBondRepository constructs a BondRepository backed by the given GORM DB.
func NewBondRepository(db *gorm.DB) BondRepository {
	return &bondRepository{db: db}
}

// ListBonds returns all bonds sorted by the requested field.
// No pagination — the full catalogue is returned in one response.
func (r *bondRepository) ListBonds(params BondQueryParams) ([]models.Bond, error) {
	// Resolve sort field — default to isin.
	dbCol, ok := validSortFields[params.SortBy]
	if !ok {
		dbCol = SortByISIN
	}

	// Normalize sort order.
	sortOrder := strings.ToLower(params.SortOrder)
	if sortOrder != "asc" && sortOrder != "desc" {
		sortOrder = "asc"
	}

	// ORDER BY <sortCol> <dir> NULLS LAST, isin <dir> as stable tiebreaker.
	orderClause := fmt.Sprintf("%s %s NULLS LAST, isin %s", string(dbCol), sortOrder, sortOrder)

	var bonds []models.Bond
	if err := r.db.Order(orderClause).Find(&bonds).Error; err != nil {
		return nil, fmt.Errorf("listing bonds: %w", err)
	}

	return bonds, nil
}

// GetBondByISIN retrieves a single bond by its primary key.
func (r *bondRepository) GetBondByISIN(isin string) (*models.Bond, error) {
	var bond models.Bond
	if err := r.db.First(&bond, "isin = ?", isin).Error; err != nil {
		return nil, err
	}
	return &bond, nil
}
