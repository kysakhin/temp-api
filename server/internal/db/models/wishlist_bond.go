package models

import (
	"time"

	"github.com/google/uuid"
)

// WishlistBond maps to the `wishlist_bonds` join table.
// The composite primary key is (wishlist_id, bond_isin).
type WishlistBond struct {
	WishlistID uuid.UUID `gorm:"primaryKey;type:uuid;column:wishlist_id"`
	BondISIN   string    `gorm:"primaryKey;column:bond_isin"`
	CreatedAt  time.Time `gorm:"column:created_at;autoCreateTime"`
}

func (WishlistBond) TableName() string {
	return "wishlist_bonds"
}
