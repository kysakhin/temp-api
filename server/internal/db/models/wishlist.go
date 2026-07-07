package models

import (
	"time"

	"github.com/google/uuid"
)

// Wishlist maps to the `wishlists` table.
type Wishlist struct {
	ID        uuid.UUID `gorm:"primaryKey;type:uuid;column:id"`
	Name      string    `gorm:"column:name;not null"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime"`
	UpdatedAt time.Time `gorm:"column:updated_at;autoUpdateTime"`
}

func (Wishlist) TableName() string {
	return "wishlists"
}
