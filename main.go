package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// configPath returns the path to triggers.json, same on all platforms:
// $XDG_CONFIG_HOME/xpandr/triggers.json
// or, if XDG_CONFIG_HOME is unset, $HOME/.config/xpandr/triggers.json
func configPath() (string, error) {
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		configHome = filepath.Join(home, ".config")
	}

	dir := filepath.Join(configHome, "xpandr")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}

	return filepath.Join(dir, "triggers.json"), nil
}

// loadStore loads the triggers file as a flat map[string]string.
func loadStore() (map[string]string, error) {
	path, err := configPath()
	if err != nil {
		return nil, err
	}

	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		// No file yet: start with an empty store.
		return map[string]string{}, nil
	}
	if err != nil {
		return nil, err
	}

	var store map[string]string
	if err := json.Unmarshal(data, &store); err != nil {
		return nil, err
	}
	if store == nil {
		store = make(map[string]string)
	}
	return store, nil
}

func saveStore(store map[string]string) error {
	path, err := configPath()
	if err != nil {
		return err
	}
	data, err := json.MarshalIndent(store, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o644)
}

func cmdAdd(args []string) error {
	fs := flag.NewFlagSet("add", flag.ExitOnError)
	_ = fs.Parse(args)
	rest := fs.Args()
	if len(rest) < 2 {
		return fmt.Errorf("usage: xpandr add SHORT EXPANSION...")
	}
	short := rest[0]
	expansion := strings.Join(rest[1:], " ")

	store, err := loadStore()
	if err != nil {
		return err
	}
	if store == nil {
		store = make(map[string]string)
	}
	store[short] = expansion
	return saveStore(store)
}

func cmdExpand(args []string) error {
	fs := flag.NewFlagSet("expand", flag.ExitOnError)
	_ = fs.Parse(args)
	rest := fs.Args()
	if len(rest) != 1 {
		return fmt.Errorf("usage: xpandr expand WORD")
	}
	word := rest[0]

	store, err := loadStore()
	if err != nil {
		return err
	}
	if exp, ok := store[word]; ok {
		fmt.Print(exp)
	} else {
		// If we don't know it, just print the original word back.
		fmt.Print(word)
	}
	return nil
}

func cmdList(args []string) error {
	fs := flag.NewFlagSet("list", flag.ExitOnError)
	_ = fs.Parse(args)

	store, err := loadStore()
	if err != nil {
		return err
	}
	if len(store) == 0 {
		fmt.Println("No triggers defined.")
		return nil
	}
	for k, v := range store {
		fmt.Printf("%-15s -> %s\n", k, v)
	}
	return nil
}

func cmdRm(args []string) error {
	fs := flag.NewFlagSet("rm", flag.ExitOnError)
	_ = fs.Parse(args)
	rest := fs.Args()
	if len(rest) != 1 {
		return fmt.Errorf("usage: xpandr rm SHORT")
	}
	short := rest[0]

	store, err := loadStore()
	if err != nil {
		return err
	}
	if _, ok := store[short]; !ok {
		return fmt.Errorf("no such abbreviation: %s", short)
	}
	delete(store, short)
	return saveStore(store)
}

func cmdDump(args []string) error {
	fs := flag.NewFlagSet("dump", flag.ExitOnError)
	_ = fs.Parse(args)

	store, err := loadStore()
	if err != nil {
		return err
	}
	for k, v := range store {
		fmt.Printf("%s\t%s\n", k, v)
	}
	return nil
}

func usage() {
	fmt.Fprintf(os.Stderr, `Usage:
  xpandr add SHORT EXPANSION...
  xpandr expand WORD
  xpandr list
  xpandr rm SHORT
  xpandr dump

Examples:
  xpandr add gc "git commit"
  xpandr expand gc
`)
	os.Exit(2)
}

func main() {
	if len(os.Args) < 2 {
		usage()
	}
	cmd := os.Args[1]
	args := os.Args[2:]

	var err error
	switch cmd {
	case "add":
		err = cmdAdd(args)
	case "expand":
		err = cmdExpand(args)
	case "list":
		err = cmdList(args)
	case "rm":
		err = cmdRm(args)
	case "dump":
		err = cmdDump(args)
	case "-h", "--help", "help":
		usage()
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n\n", cmd)
		usage()
	}

	if err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}
}
