package repository

import (
	"fmt"

	"github.com/google/uuid"
	"github.com/kysakhin/temp-api/internal/db/models"
	"gorm.io/gorm"
)

// WishlistWithBonds is a projection used by GetWishlistWithBonds.
type WishlistWithBonds struct {
	models.Wishlist
	Bonds []models.Bond
}

// WishlistRepository defines the data-access contract for wishlists.
type WishlistRepository interface {
	ListWishlists() ([]models.Wishlist, error)
	GetWishlistByID(id uuid.UUID) (*models.Wishlist, error)
	CountWishlists() (int64, error)
	CreateWishlist(name string) (*models.Wishlist, error)
	UpdateWishlistName(id uuid.UUID, name string) (*models.Wishlist, error)
	DeleteWishlist(id uuid.UUID) error
	GetWishlistWithBonds(id uuid.UUID) (*WishlistWithBonds, error)
	CountBondsInWishlist(id uuid.UUID) (int64, error)
	BondExistsInWishlist(wishlistID uuid.UUID, isin string) (bool, error)
	AddBondToWishlist(wishlistID uuid.UUID, isin string) error
	RemoveBondFromWishlist(wishlistID uuid.UUID, isin string) error
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
	// Re-fetch to get the updated_at timestamp from the DB.
	return r.GetWishlistByID(id)
}

// DeleteWishlist removes a wishlist and all its associated wishlist_bonds in a
// single transaction to ensure consistency.
func (r *wishlistRepository) DeleteWishlist(id uuid.UUID) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// Delete child rows first to satisfy FK constraints.
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

// GetWishlistWithBonds fetches a wishlist together with its bonds ordered by
// the time they were added (newest first).
func (r *wishlistRepository) GetWishlistWithBonds(id uuid.UUID) (*WishlistWithBonds, error) {
	var wl models.Wishlist
	if err := r.db.First(&wl, "id = ?", id).Error; err != nil {
		return nil, err
	}

	// Join wishlist_bonds to get the bonds in the correct order.
	var bonds []models.Bond
	err := r.db.
		Table("bonds b").
		Select("b.*").
		Joins("JOIN wishlist_bonds wb ON wb.bond_isin = b.isin").
		Where("wb.wishlist_id = ?", id).
		Order("wb.created_at DESC").
		Find(&bonds).Error
	if err != nil {
		return nil, fmt.Errorf("fetching wishlist bonds: %w", err)
	}

	return &WishlistWithBonds{
		Wishlist: wl,
		Bonds:    bonds,
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

// AddBondToWishlist inserts a wishlist_bond row.
func (r *wishlistRepository) AddBondToWishlist(wishlistID uuid.UUID, isin string) error {
	wb := models.WishlistBond{
		WishlistID: wishlistID,
		BondISIN:   isin,
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
