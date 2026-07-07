package config

import (
	"fmt"
	"os"

	"github.com/joho/godotenv"
)

// Config holds all application configuration loaded from environment variables.
type Config struct {
	DatabaseURL string
	Port        string
}

// Load reads the .env file (if present) and returns a populated Config.
// Missing required variables will cause an error.
func Load() (*Config, error) {
	// godotenv.Load is a no-op if the file does not exist (e.g. in production
	// where env vars are injected directly). We only fail on real parse errors.
	if err := godotenv.Load(); err != nil && !os.IsNotExist(err) {
		return nil, fmt.Errorf("loading .env: %w", err)
	}

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		return nil, fmt.Errorf("DATABASE_URL environment variable is required")
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	return &Config{
		DatabaseURL: dbURL,
		Port:        port,
	}, nil
}
