//go:build ignore

package main

import (
	"fmt"
	"os"
)

func main() {
	directories := []string{
		"internal/api/coingecko",
		"internal/api/forex",
		"internal/api/fred",
	}

	fmt.Println("Creating directories...\n")

	for _, dir := range directories {
		err := os.MkdirAll(dir, 0755)
		if err != nil {
			fmt.Printf("✗ Failed to create %s: %v\n", dir, err)
			os.Exit(1)
		}
		fmt.Printf("✓ Created: %s\n", dir)
	}

	fmt.Println("\nVerifying directories:")
	allExist := true
	for _, dir := range directories {
		info, err := os.Stat(dir)
		if err == nil && info.IsDir() {
			fmt.Printf("✓ Verified: %s exists\n", dir)
		} else {
			fmt.Printf("✗ Missing: %s\n", dir)
			allExist = false
		}
	}

	if allExist {
		fmt.Println("\n✓ All directories created successfully!")
	} else {
		fmt.Println("\n✗ Some directories are missing")
		os.Exit(1)
	}
}
