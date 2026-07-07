package models

import (
	"time"

	"github.com/shopspring/decimal"
)

// Bond maps to the `bonds` table.
// All nullable columns are represented as pointers so GORM correctly
// handles NULL vs zero-value distinctions.
type Bond struct {
	ISIN            string           `gorm:"primaryKey;column:isin"`
	BondName        string           `gorm:"column:bond_name;not null"`
	Rating          *string          `gorm:"column:rating"`
	BondYield       *decimal.Decimal `gorm:"column:bond_yield;type:decimal(6,2)"`
	MinInvestment   *int64           `gorm:"column:min_investment"`
	PayoutFrequency *string          `gorm:"column:payout_frequency"`
	LogoURL         *string          `gorm:"column:logo_url"`
	DetailURL       *string          `gorm:"column:detail_url"`
	Tenure          decimal.Decimal  `gorm:"column:tenure;type:decimal(6,2);not null"`
	MaturityDate    *time.Time       `gorm:"column:maturity_date;type:date"`
	Color           *string          `gorm:"column:color"`
}

func (Bond) TableName() string {
	return "bonds"
}
