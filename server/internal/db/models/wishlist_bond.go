package models

import (
	"time"

	"github.com/google/uuid"
)

// WishlistBond maps to the `wishlist_bonds` join table.
// The composite primary key is (wishlist_id, bond_isin).
// Color and Position are per-wishlist-bond — a bond can have a different
// appearance and ordering in each wishlist it belongs to.
type WishlistBond struct {
	WishlistID uuid.UUID `gorm:"primaryKey;type:uuid;column:wishlist_id"`
	BondISIN   string    `gorm:"primaryKey;column:bond_isin"`
	Color      *string   `gorm:"column:color"`
	Position   int       `gorm:"column:position;not null;default:0"`
	IsPinned   bool      `gorm:"column:is_pinned;not null;default:false"`
	CreatedAt  time.Time `gorm:"column:created_at;autoCreateTime"`
}

func (WishlistBond) TableName() string {
	return "wishlist_bonds"
}
