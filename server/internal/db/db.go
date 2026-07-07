package db

import (
	"fmt"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Connect opens a GORM connection to PostgreSQL using the provided DSN.
// Tables are managed via the SQL migration files in /migrations — AutoMigrate
// is intentionally not called here.
func Connect(databaseURL string) (*gorm.DB, error) {
	db, err := gorm.Open(postgres.Open(databaseURL), &gorm.Config{
		// Use silent logger in production; swap to logger.Default for debugging.
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		return nil, fmt.Errorf("opening database connection: %w", err)
	}

	// Verify the connection is live.
	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("retrieving underlying sql.DB: %w", err)
	}
	if err := sqlDB.Ping(); err != nil {
		return nil, fmt.Errorf("pinging database: %w", err)
	}

	return db, nil
}
