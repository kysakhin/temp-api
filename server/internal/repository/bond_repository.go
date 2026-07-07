package repository

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/kysakhin/temp-api/internal/db/models"
	"gorm.io/gorm"
)

// BondSortField enumerates the columns by which bonds can be sorted.
type BondSortField string

const (
	SortByISIN            BondSortField = "isin"
	SortByBondYield       BondSortField = "bond_yield"
	SortByMinInvestment   BondSortField = "min_investment"
	SortByTenure          BondSortField = "tenure"
	SortByRating          BondSortField = "rating"
)

// validSortFields maps the client-facing camelCase param to the DB column name.
var validSortFields = map[string]BondSortField{
	"isin":          SortByISIN,
	"bondYield":     SortByBondYield,
	"minInvestment": SortByMinInvestment,
	"tenure":        SortByTenure,
	"rating":        SortByRating,
}

// BondQueryParams carries all parameters needed to list bonds with pagination.
type BondQueryParams struct {
	Limit     int
	Cursor    string // opaque base64 cursor
	SortBy    string // client param name, e.g. "bondYield"
	SortOrder string // "asc" | "desc"
}

// bondCursor is the internal representation of the opaque cursor.
type bondCursor struct {
	SortBy    string `json:"sortBy"`
	SortOrder string `json:"sortOrder"`
	SortVal   string `json:"sortVal"` // stringified value of the sort field for the last item; "null" if NULL
	ISIN      string `json:"isin"`    // tiebreaker
}

// BondRepository defines the data-access contract for bonds.
type BondRepository interface {
	ListBonds(params BondQueryParams) ([]models.Bond, error)
	GetBondByISIN(isin string) (*models.Bond, error)
	UpdateBondColor(isin string, color *string) error
}

type bondRepository struct {
	db *gorm.DB
}

// NewBondRepository constructs a BondRepository backed by the given GORM DB.
func NewBondRepository(db *gorm.DB) BondRepository {
	return &bondRepository{db: db}
}

// ListBonds returns a page of bonds using keyset (cursor-based) pagination.
func (r *bondRepository) ListBonds(params BondQueryParams) ([]models.Bond, error) {
	// Resolve sort field — default to isin.
	dbCol, ok := validSortFields[params.SortBy]
	if !ok {
		dbCol = SortByISIN
		params.SortBy = "isin"
	}

	// Normalize sort order.
	sortOrder := strings.ToLower(params.SortOrder)
	if sortOrder != "asc" && sortOrder != "desc" {
		sortOrder = "asc"
	}

	// Decode cursor if present.
	var cur *bondCursor
	if params.Cursor != "" {
		decoded, err := decodeCursor(params.Cursor)
		if err == nil &&
			decoded.SortBy == params.SortBy &&
			decoded.SortOrder == sortOrder {
			cur = decoded
		}
		// If cursor is stale (sort context changed), we simply ignore it and
		// start from page 1 — no error returned to client.
	}

	q := r.db.Model(&models.Bond{})

	// Apply keyset WHERE clause when a valid cursor is present.
	if cur != nil {
		q = applyKeysetWhere(q, dbCol, sortOrder, cur)
	}

	// ORDER BY <sortCol> <dir> NULLS LAST, isin <dir>
	// Using isin as a stable tiebreaker guarantees deterministic pagination.
	orderClause := fmt.Sprintf("%s %s NULLS LAST, isin %s", string(dbCol), sortOrder, sortOrder)
	q = q.Order(orderClause)

	// Fetch limit+1 to determine whether a next page exists.
	limit := params.Limit
	if limit <= 0 {
		limit = 20
	}

	var bonds []models.Bond
	if err := q.Limit(limit + 1).Find(&bonds).Error; err != nil {
		return nil, fmt.Errorf("listing bonds: %w", err)
	}

	return bonds, nil
}

// applyKeysetWhere builds the WHERE clause for keyset pagination.
// For ascending nullable column (e.g. bondYield):
//
//	WHERE (bond_yield > :val OR (bond_yield = :val AND isin > :isin))
//	  OR  (bond_yield IS NULL AND isin > :isin)   -- when cursor had non-null val
//
// For the NULL case (cursor item had NULL sort value):
//
//	WHERE bond_yield IS NULL AND isin > :isin
func applyKeysetWhere(q *gorm.DB, col BondSortField, order string, cur *bondCursor) *gorm.DB {
	colStr := string(col)

	if col == SortByISIN {
		// Simple case: isin is PK, never null.
		if order == "asc" {
			return q.Where("isin > ?", cur.ISIN)
		}
		return q.Where("isin < ?", cur.ISIN)
	}

	if cur.SortVal == "null" {
		// Cursor item had NULL sort value. Since we use NULLS LAST,
		// remaining items with NULL come after; tiebreak on isin.
		if order == "asc" {
			return q.Where(colStr+" IS NULL AND isin > ?", cur.ISIN)
		}
		return q.Where(colStr+" IS NULL AND isin < ?", cur.ISIN)
	}

	// Cursor item had a non-null sort value.
	if order == "asc" {
		// Rows where sort col > cursor val, OR equal with later isin,
		// OR sort col IS NULL (they come at the end with NULLS LAST but
		// are still "after" a non-null cursor).
		return q.Where(
			"("+colStr+" > ? OR ("+colStr+" = ? AND isin > ?)) OR "+colStr+" IS NULL",
			cur.SortVal, cur.SortVal, cur.ISIN,
		)
	}
	// desc: NULL values appear last (NULLS LAST), so they do NOT appear after a non-null cursor in desc order.
	return q.Where(
		colStr+" < ? OR ("+colStr+" = ? AND isin < ?)",
		cur.SortVal, cur.SortVal, cur.ISIN,
	)
}

// GetBondByISIN retrieves a single bond by its primary key.
func (r *bondRepository) GetBondByISIN(isin string) (*models.Bond, error) {
	var bond models.Bond
	if err := r.db.First(&bond, "isin = ?", isin).Error; err != nil {
		return nil, err
	}
	return &bond, nil
}

// UpdateBondColor sets the color field for the given bond.
// Passing nil clears the color (sets it to NULL).
func (r *bondRepository) UpdateBondColor(isin string, color *string) error {
	result := r.db.Model(&models.Bond{}).
		Where("isin = ?", isin).
		Update("color", color)
	if result.Error != nil {
		return fmt.Errorf("updating bond color: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

// EncodeCursor serialises a bondCursor into an opaque base64 string.
func EncodeCursor(sortBy, sortOrder, sortVal, isin string) string {
	cur := bondCursor{
		SortBy:    sortBy,
		SortOrder: sortOrder,
		SortVal:   sortVal,
		ISIN:      isin,
	}
	b, _ := json.Marshal(cur)
	return base64.URLEncoding.EncodeToString(b)
}

func decodeCursor(raw string) (*bondCursor, error) {
	b, err := base64.URLEncoding.DecodeString(raw)
	if err != nil {
		return nil, err
	}
	var cur bondCursor
	if err := json.Unmarshal(b, &cur); err != nil {
		return nil, err
	}
	return &cur, nil
}
