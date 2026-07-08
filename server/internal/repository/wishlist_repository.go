package repository

import (
	"fmt"

	"github.com/google/uuid"
	"github.com/kysakhin/temp-api/internal/db/models"
	"gorm.io/gorm"
)

// WishlistBondEntry pairs a bond with its wishlist-specific metadata.
type WishlistBondEntry struct {
	models.Bond
	Color    *string
	Position int
	IsPinned bool
}

// WishlistWithBonds is a projection used by GetWishlistWithBonds.
type WishlistWithBonds struct {
	models.Wishlist
	Bonds []WishlistBondEntry
}

// WishlistSortBy enumerates the sort options for bonds inside a wishlist.
// Pinned bonds always float to the top regardless of sort mode.
type WishlistSortBy string

const (
	WishlistSortManual        WishlistSortBy = "manual"        // pinned DESC, position ASC
	WishlistSortAddedRecently WishlistSortBy = "addedRecently" // pinned DESC, created_at DESC
	WishlistSortColor         WishlistSortBy = "color"         // pinned DESC, color ASC NULLS LAST, position ASC
	WishlistSortYield         WishlistSortBy = "yield"         // pinned DESC, bond_yield DESC NULLS LAST, position ASC
	WishlistSortMinInvestment WishlistSortBy = "minInvestment" // pinned DESC, min_investment ASC NULLS LAST, position ASC
	WishlistSortTenure        WishlistSortBy = "tenure"        // pinned DESC, tenure ASC, position ASC
	WishlistSortRating        WishlistSortBy = "rating"        // pinned DESC, custom rating ASC, position ASC
)

// WishlistRepository defines the data-access contract for wishlists.
type WishlistRepository interface {
	ListWishlists() ([]models.Wishlist, error)
	GetWishlistByID(id uuid.UUID) (*models.Wishlist, error)
	CountWishlists() (int64, error)
	WishlistExistsByName(name string, excludeID uuid.UUID) (bool, error)
	CreateWishlist(name string) (*models.Wishlist, error)
	UpdateWishlistName(id uuid.UUID, name string) (*models.Wishlist, error)
	DeleteWishlist(id uuid.UUID) error
	GetWishlistWithBonds(id uuid.UUID, sortBy WishlistSortBy) (*WishlistWithBonds, error)
	CountBondsInWishlist(id uuid.UUID) (int64, error)
	BondExistsInWishlist(wishlistID uuid.UUID, isin string) (bool, error)
	AddBondToWishlist(wishlistID uuid.UUID, isin string) error
	RemoveBondFromWishlist(wishlistID uuid.UUID, isin string) error
	UpdateWishlistBondColor(wishlistID uuid.UUID, isin string, color *string) error
	UpdateWishlistBondPosition(wishlistID uuid.UUID, isin string, position int) error
	PinWishlistBond(wishlistID uuid.UUID, isin string, isPinned bool) error
	ReorderWishlistBonds(wishlistID uuid.UUID, orderedISINs []string) error
}

type wishlistRepository struct {
	db *gorm.DB
}

// NewWishlistRepository constructs a WishlistRepository backed by the given GORM DB.
func NewWishlistRepository(db *gorm.DB) WishlistRepository {
	return &wishlistRepository{db: db}
}

// ListWishlists returns all wishlists ordered newest first.
func (r *wishlistRepository) ListWishlists() ([]models.Wishlist, error) {
	var wishlists []models.Wishlist
	if err := r.db.Order("created_at DESC").Find(&wishlists).Error; err != nil {
		return nil, fmt.Errorf("listing wishlists: %w", err)
	}
	return wishlists, nil
}

// GetWishlistByID retrieves a single wishlist by its UUID.
func (r *wishlistRepository) GetWishlistByID(id uuid.UUID) (*models.Wishlist, error) {
	var wl models.Wishlist
	if err := r.db.First(&wl, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return &wl, nil
}

// CountWishlists returns the total number of wishlists in the database.
func (r *wishlistRepository) CountWishlists() (int64, error) {
	var count int64
	if err := r.db.Model(&models.Wishlist{}).Count(&count).Error; err != nil {
		return 0, fmt.Errorf("counting wishlists: %w", err)
	}
	return count, nil
}

// WishlistExistsByName checks if a wishlist with the exact name already exists, optionally excluding a specific ID.
func (r *wishlistRepository) WishlistExistsByName(name string, excludeID uuid.UUID) (bool, error) {
	var count int64
	q := r.db.Model(&models.Wishlist{}).Where("name = ?", name)
	if excludeID != uuid.Nil {
		q = q.Where("id != ?", excludeID)
	}
	err := q.Count(&count).Error
	return count > 0, err
}

// CreateWishlist inserts a new wishlist and returns the created record.
func (r *wishlistRepository) CreateWishlist(name string) (*models.Wishlist, error) {
	wl := models.Wishlist{
		ID:   uuid.New(),
		Name: name,
	}
	if err := r.db.Create(&wl).Error; err != nil {
		return nil, fmt.Errorf("creating wishlist: %w", err)
	}
	return &wl, nil
}

// UpdateWishlistName renames the specified wishlist and returns the updated record.
func (r *wishlistRepository) UpdateWishlistName(id uuid.UUID, name string) (*models.Wishlist, error) {
	result := r.db.Model(&models.Wishlist{}).
		Where("id = ?", id).
		Update("name", name)
	if result.Error != nil {
		return nil, fmt.Errorf("updating wishlist: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return nil, gorm.ErrRecordNotFound
	}
	return r.GetWishlistByID(id)
}

// DeleteWishlist removes a wishlist and all its associated wishlist_bonds in a transaction.
func (r *wishlistRepository) DeleteWishlist(id uuid.UUID) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("wishlist_id = ?", id).Delete(&models.WishlistBond{}).Error; err != nil {
			return fmt.Errorf("deleting wishlist bonds: %w", err)
		}
		result := tx.Where("id = ?", id).Delete(&models.Wishlist{})
		if result.Error != nil {
			return fmt.Errorf("deleting wishlist: %w", result.Error)
		}
		if result.RowsAffected == 0 {
			return gorm.ErrRecordNotFound
		}
		return nil
	})
}

// GetWishlistWithBonds fetches a wishlist and its bonds with wishlist-specific metadata.
// Pinned bonds always appear first, then secondary sort is applied within each group.
func (r *wishlistRepository) GetWishlistWithBonds(id uuid.UUID, sortBy WishlistSortBy) (*WishlistWithBonds, error) {
	var wl models.Wishlist
	if err := r.db.First(&wl, "id = ?", id).Error; err != nil {
		return nil, err
	}

	// Pinned bonds always float to top. Secondary sort depends on user preference.
	var secondaryOrder string
	switch sortBy {
	case WishlistSortAddedRecently:
		secondaryOrder = "wb.created_at DESC"
	case WishlistSortColor:
		secondaryOrder = "wb.color ASC NULLS LAST, wb.position ASC"
	case WishlistSortYield:
		secondaryOrder = "b.bond_yield DESC NULLS LAST, wb.position ASC"
	case "minInvestment":
		secondaryOrder = "b.min_investment ASC NULLS LAST, wb.position ASC"
	case WishlistSortTenure:
		secondaryOrder = "b.tenure ASC, wb.position ASC"
	case WishlistSortRating:
		secondaryOrder = "array_position(ARRAY['AAA', 'AA+', 'AA', 'AA-', 'A+', 'A', 'A-', 'BBB+', 'BBB', 'BBB-', 'BB+', 'BB', 'BB-', 'B+', 'B', 'B-', 'CCC+', 'CCC', 'CCC-', 'CC', 'C', 'D']::varchar[], REPLACE(b.rating, '−', '-')) ASC NULLS LAST, wb.position ASC"
	default: // WishlistSortManual
		secondaryOrder = "wb.position ASC"
	}
	orderClause := "wb.is_pinned DESC, " + secondaryOrder

	type row struct {
		models.Bond
		WBColor    *string `gorm:"column:wb_color"`
		WBPosition int     `gorm:"column:wb_position"`
		WBIsPinned bool    `gorm:"column:wb_is_pinned"`
	}

	var rows []row
	err := r.db.
		Table("bonds b").
		Select("b.*, wb.color AS wb_color, wb.position AS wb_position, wb.is_pinned AS wb_is_pinned").
		Joins("JOIN wishlist_bonds wb ON wb.bond_isin = b.isin").
		Where("wb.wishlist_id = ?", id).
		Order(orderClause).
		Scan(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("fetching wishlist bonds: %w", err)
	}

	entries := make([]WishlistBondEntry, len(rows))
	for i, row := range rows {
		entries[i] = WishlistBondEntry{
			Bond:     row.Bond,
			Color:    row.WBColor,
			Position: row.WBPosition,
			IsPinned: row.WBIsPinned,
		}
	}

	return &WishlistWithBonds{
		Wishlist: wl,
		Bonds:    entries,
	}, nil
}

// CountBondsInWishlist returns how many bonds are currently in a wishlist.
func (r *wishlistRepository) CountBondsInWishlist(id uuid.UUID) (int64, error) {
	var count int64
	if err := r.db.Model(&models.WishlistBond{}).
		Where("wishlist_id = ?", id).
		Count(&count).Error; err != nil {
		return 0, fmt.Errorf("counting bonds in wishlist: %w", err)
	}
	return count, nil
}

// BondExistsInWishlist checks whether a bond is already in the wishlist.
func (r *wishlistRepository) BondExistsInWishlist(wishlistID uuid.UUID, isin string) (bool, error) {
	var count int64
	err := r.db.Model(&models.WishlistBond{}).
		Where("wishlist_id = ? AND bond_isin = ?", wishlistID, isin).
		Count(&count).Error
	return count > 0, err
}

// AddBondToWishlist inserts a wishlist_bond row with position 0 and unpinned by default.
func (r *wishlistRepository) AddBondToWishlist(wishlistID uuid.UUID, isin string) error {
	wb := models.WishlistBond{
		WishlistID: wishlistID,
		BondISIN:   isin,
		Position:   0,
		IsPinned:   false,
	}
	if err := r.db.Create(&wb).Error; err != nil {
		return fmt.Errorf("adding bond to wishlist: %w", err)
	}
	return nil
}

// RemoveBondFromWishlist deletes the wishlist_bond row for the given pair.
func (r *wishlistRepository) RemoveBondFromWishlist(wishlistID uuid.UUID, isin string) error {
	result := r.db.
		Where("wishlist_id = ? AND bond_isin = ?", wishlistID, isin).
		Delete(&models.WishlistBond{})
	if result.Error != nil {
		return fmt.Errorf("removing bond from wishlist: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

// UpdateWishlistBondColor sets the tag color for a bond within a specific wishlist.
func (r *wishlistRepository) UpdateWishlistBondColor(wishlistID uuid.UUID, isin string, color *string) error {
	result := r.db.Model(&models.WishlistBond{}).
		Where("wishlist_id = ? AND bond_isin = ?", wishlistID, isin).
		Update("color", color)
	if result.Error != nil {
		return fmt.Errorf("updating wishlist bond color: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

// UpdateWishlistBondPosition sets the manual display position for a bond in a wishlist.
func (r *wishlistRepository) UpdateWishlistBondPosition(wishlistID uuid.UUID, isin string, position int) error {
	result := r.db.Model(&models.WishlistBond{}).
		Where("wishlist_id = ? AND bond_isin = ?", wishlistID, isin).
		Update("position", position)
	if result.Error != nil {
		return fmt.Errorf("updating wishlist bond position: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

// PinWishlistBond sets or clears the is_pinned flag for a bond in a wishlist.
// Pinned bonds always appear before unpinned bonds in all sort modes.
func (r *wishlistRepository) PinWishlistBond(wishlistID uuid.UUID, isin string, isPinned bool) error {
	result := r.db.Model(&models.WishlistBond{}).
		Where("wishlist_id = ? AND bond_isin = ?", wishlistID, isin).
		Update("is_pinned", isPinned)
	if result.Error != nil {
		return fmt.Errorf("pinning wishlist bond: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

// ReorderWishlistBonds bulk-updates position for all bonds in a wishlist.
// The index of each ISIN in orderedISINs becomes its new position (0-based).
// Pinned bonds keep their is_pinned flag and will still appear first in queries
// due to ORDER BY is_pinned DESC — positions only determine order within
// the pinned group and within the unpinned group independently.
func (r *wishlistRepository) ReorderWishlistBonds(wishlistID uuid.UUID, orderedISINs []string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		for i, isin := range orderedISINs {
			result := tx.Model(&models.WishlistBond{}).
				Where("wishlist_id = ? AND bond_isin = ?", wishlistID, isin).
				Update("position", i)
			if result.Error != nil {
				return fmt.Errorf("reordering bond %s: %w", isin, result.Error)
			}
			if result.RowsAffected == 0 {
				return fmt.Errorf("bond %s not found in wishlist", isin)
			}
		}
		return nil
	})
}
