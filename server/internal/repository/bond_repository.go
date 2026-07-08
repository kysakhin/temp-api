package repository

import (
	"fmt"
	"math"
	"sort"
	"strings"

	"github.com/kysakhin/temp-api/internal/db/models"
	"gorm.io/gorm"
)

// BondSortField enumerates the columns by which bonds can be sorted.
type BondSortField string

const (
	SortByISIN          BondSortField = "isin"
	SortByBondYield     BondSortField = "yield"
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
	SearchBonds(query string) ([]models.Bond, error)
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

	var orderClause string
	if dbCol == SortByRating {
		orderClause = fmt.Sprintf("array_position(ARRAY['AAA', 'AA+', 'AA', 'AA-', 'A+', 'A', 'A-', 'BBB+', 'BBB', 'BBB-', 'BB+', 'BB', 'BB-', 'B+', 'B', 'B-', 'CCC+', 'CCC', 'CCC-', 'CC', 'C', 'D']::varchar[], REPLACE(rating, '−', '-')) %s NULLS LAST, isin %s", sortOrder, sortOrder)
	} else {
		// ORDER BY <sortCol> <dir> NULLS LAST, isin <dir> as stable tiebreaker.
		orderClause = fmt.Sprintf("%s %s NULLS LAST, isin %s", string(dbCol), sortOrder, sortOrder)
	}

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

type bondMatch struct {
	bond  models.Bond
	score int
}

// SearchBonds returns bonds matching the query using custom fuzzy search.
func (r *bondRepository) SearchBonds(query string) ([]models.Bond, error) {
	// Fetch all bonds into memory (feasible since catalog has no pagination)
	var allBonds []models.Bond
	if err := r.db.Find(&allBonds).Error; err != nil {
		return nil, fmt.Errorf("fetching bonds for search: %w", err)
	}

	var matches []bondMatch
	for _, b := range allBonds {
		// Combine ISIN and BondName to allow fuzzy matching across both fields seamlessly
		target := b.ISIN + " " + b.BondName
		score := customFuzzyMatch(query, target)
		if score > math.MinInt32 {
			matches = append(matches, bondMatch{bond: b, score: score})
		}
	}

	// Sort by score DESC
	sort.SliceStable(matches, func(i, j int) bool {
		return matches[i].score > matches[j].score
	})

	results := make([]models.Bond, len(matches))
	for i, m := range matches {
		results[i] = m.bond
	}

	return results, nil
}

func customFuzzyMatch(pattern, str string) int {
	const unmatchedLetterPenalty = -1
	const exactMatchBonus = 1000
	slen := len(str)
	plen := len(pattern)
	score := 100

	if plen == 0 {
		return score
	}
	if slen < plen {
		return math.MinInt32
	}

	if customIsExactMatch(pattern, str) {
		return score + exactMatchBonus
	}

	idx := strings.IndexByte(str, '(')
	if idx != -1 {
		prefixLen := idx
		if prefixLen == plen && customIsExactMatch(pattern, str) {
			return score + exactMatchBonus - 50
		}
	}

	score += unmatchedLetterPenalty * (slen - plen)
	return customFuzzyMatchRecurse(pattern, 0, score, true, str, 0)
}

func customIsExactMatch(pattern, str string) bool {
	i := 0
	for i < len(pattern) && i < len(str) {
		if customToLower(pattern[i]) != customToLower(str[i]) {
			return false
		}
		i++
	}
	return i == len(pattern)
}

func customFuzzyMatchRecurse(pattern string, pIdx int, score int, firstChar bool, fullStr string, sIdx int) int {
	if pIdx == len(pattern) {
		return score
	}

	bestScore := math.MinInt32
	searchChar := customToLower(pattern[pIdx])

	// Original C logic had a quirk where at_word_start was always evaluated as true
	// bool at_word_start = (str == match || !isalnum((unsigned char)*(str-1)));
	// Since match was just assigned to str, str == match was tautologically true.
	atWordStart := true
	if atWordStart {
		score += 50
	}

	matchIdx := sIdx
	for matchIdx < len(fullStr) {
		if customToLower(fullStr[matchIdx]) == searchChar {
			jump := matchIdx - sIdx
			subscore := customFuzzyMatchRecurse(
				pattern, pIdx+1,
				customComputeScore(jump, firstChar, fullStr, matchIdx),
				false, fullStr, matchIdx+1,
			)
			if subscore > bestScore {
				bestScore = subscore
			}
		}
		matchIdx++
	}

	if bestScore == math.MinInt32 {
		return math.MinInt32
	}
	return score + bestScore
}

func customComputeScore(jump int, firstChar bool, fullStr string, matchIdx int) int {
	const adjacencyBonus = 15
	const separatorBonus = 30
	const camelBonus = 30
	const firstLetterBonus = 15
	const leadingLetterPenalty = -5
	const maxLeadingLetterPenalty = -15
	const consecutiveMatchBonus = 40

	score := 0

	if !firstChar && jump == 0 {
		score += adjacencyBonus + consecutiveMatchBonus
	}

	if (!firstChar || jump > 0) && matchIdx > 0 {
		matchChar := fullStr[matchIdx]
		prevChar := fullStr[matchIdx-1]

		if customIsUpper(matchChar) && customIsLower(prevChar) {
			score += camelBonus
		}
		if customIsAlnum(matchChar) && !customIsAlnum(prevChar) {
			score += separatorBonus
		}
	}

	if firstChar && jump == 0 {
		score += firstLetterBonus
	}
	if firstChar {
		penalty := leadingLetterPenalty * jump
		if penalty < maxLeadingLetterPenalty {
			penalty = maxLeadingLetterPenalty
		}
		score += penalty
	}

	return score
}

func customToLower(b byte) byte {
	if b >= 'A' && b <= 'Z' {
		return b + 32
	}
	return b
}

func customIsAlnum(b byte) bool {
	return (b >= 'A' && b <= 'Z') || (b >= 'a' && b <= 'z') || (b >= '0' && b <= '9')
}

func customIsUpper(b byte) bool {
	return b >= 'A' && b <= 'Z'
}

func customIsLower(b byte) bool {
	return b >= 'a' && b <= 'z'
}
