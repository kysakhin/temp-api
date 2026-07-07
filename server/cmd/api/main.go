package main

import (
	"fmt"
	"log"

	"github.com/kysakhin/temp-api/internal/config"
	"github.com/kysakhin/temp-api/internal/db"
	"github.com/kysakhin/temp-api/internal/handlers"
	"github.com/kysakhin/temp-api/internal/repository"
)

func main() {
	// 1. Load configuration from environment / .env file.
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	// 2. Connect to PostgreSQL.
	database, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("database: %v", err)
	}

	// 3. Wire up repositories.
	bondRepo := repository.NewBondRepository(database)
	wishlistRepo := repository.NewWishlistRepository(database)

	// 4. Build the Gin router.
	router := handlers.NewRouter(bondRepo, wishlistRepo)

	// 5. Start the server.
	addr := fmt.Sprintf(":%s", cfg.Port)
	log.Printf("server listening on %s", addr)
	if err := router.Run(addr); err != nil {
		log.Fatalf("server: %v", err)
	}
}
