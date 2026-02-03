package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
)

// SensitiveFilesGuard checks for forbidden sensitive files in the repository
type SensitiveFilesGuard struct {
	sensitivePatterns []*regexp.Regexp
	ignorePatterns    []*regexp.Regexp
}

// Sensitive file patterns that should never be committed
var sensitivePatternStrings = []string{
	`(^|/)(config\.yaml)$`,
	`(^|/)(ansible|terraform)/op\.env$`,
	`(^|/)\.env([._-].*)?$`,
	`(^|/)(kubeconfig)(\..*)?$`,
	`(^|/).*id_(rsa|ed25519)(\..*)?$`,
	`(^|/).*\.p12$`,
	`(^|/).*\.pfx$`,
	`(^|/).*\.key$`,
	`(^|/).*privkey.*\.pem$`,
	`(^|/).*private.*\.pem$`,
	`(^|/).*terraform\.tfstate(\..*)?$`,
	`(^|/).*\.tfstate\..*$`,
	`(^|/).*secrets\.auto\.tfvars$`,
	`(^|/).*\.tfvars$`,
	`(^|/).*-(unsealed)\.ya?ml$`,
	`(^|/).*unsealed.*\.ya?ml$`,
}

// Ignore patterns for allowed exceptions
var ignorePatternStrings = []string{
	`(^|/)apps/cluster/secrets-cluster/`,
	`(^|/)apps/cluster/sealed-secrets/`,
	`\.sealedsecret\.ya?ml$`,
	`(^|/)docs/archive/`,
	`(^|/)apps/.*/charts/`,
	`(^|/)apps/.*/Chart\.lock$`,
	`(^|/)ansible/roles/.*/tasks/config\.yaml$`,
	`(^|/)ansible/roles/.*/handlers/config\.yaml$`,
	`defaults\.auto\.tfvars$`,
}

func NewSensitiveFilesGuard() (*SensitiveFilesGuard, error) {
	guard := &SensitiveFilesGuard{
		sensitivePatterns: make([]*regexp.Regexp, 0, len(sensitivePatternStrings)),
		ignorePatterns:    make([]*regexp.Regexp, 0, len(ignorePatternStrings)),
	}

	// Compile sensitive patterns
	for _, pattern := range sensitivePatternStrings {
		re, err := regexp.Compile(pattern)
		if err != nil {
			return nil, fmt.Errorf("failed to compile sensitive pattern %q: %w", pattern, err)
		}
		guard.sensitivePatterns = append(guard.sensitivePatterns, re)
	}

	// Compile ignore patterns
	for _, pattern := range ignorePatternStrings {
		re, err := regexp.Compile(pattern)
		if err != nil {
			return nil, fmt.Errorf("failed to compile ignore pattern %q: %w", pattern, err)
		}
		guard.ignorePatterns = append(guard.ignorePatterns, re)
	}

	return guard, nil
}

func (g *SensitiveFilesGuard) isSensitive(path string) bool {
	for _, re := range g.sensitivePatterns {
		if re.MatchString(path) {
			return true
		}
	}
	return false
}

func (g *SensitiveFilesGuard) isIgnored(path string) bool {
	for _, re := range g.ignorePatterns {
		if re.MatchString(path) {
			return true
		}
	}
	return false
}

func (g *SensitiveFilesGuard) Check(files []string) []string {
	matches := []string{}

	for _, file := range files {
		if file == "" {
			continue
		}

		// Check if file matches sensitive patterns
		if !g.isSensitive(file) {
			continue
		}

		// Check if file is in ignore list
		if g.isIgnored(file) {
			continue
		}

		matches = append(matches, file)
	}

	return matches
}

func getGitFiles() ([]string, error) {
	// Use absolute path to git for security
	gitPath := "/usr/bin/git"

	// Try to get staged files first (pre-commit hook)
	cmd := exec.Command(gitPath, "diff", "--cached", "--name-only", "--diff-filter=ACMR")
	// Set secure PATH to prevent PATH injection attacks
	cmd.Env = append(os.Environ(), "PATH=/usr/bin:/bin:/usr/sbin:/sbin")
	output, err := cmd.Output()
	if err == nil && len(output) > 0 {
		files := strings.Split(strings.TrimSpace(string(output)), "\n")
		if len(files) > 0 && files[0] != "" {
			return files, nil
		}
	}

	// Fallback to all tracked files (CI)
	cmd = exec.Command(gitPath, "ls-files")
	cmd.Env = append(os.Environ(), "PATH=/usr/bin:/bin:/usr/sbin:/sbin")
	output, err = cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to get git files: %w", err)
	}

	files := strings.Split(strings.TrimSpace(string(output)), "\n")
	return files, nil
}

func main() {
	listPatterns := flag.Bool("list-patterns", false, "List all sensitive and ignore patterns")
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [options]\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "\nCheck for forbidden sensitive files in the repository.\n\n")
		fmt.Fprintf(os.Stderr, "This tool scans staged files (pre-commit) or all tracked files (CI)\n")
		fmt.Fprintf(os.Stderr, "and reports any matches against sensitive file patterns, excluding\n")
		fmt.Fprintf(os.Stderr, "allowed exceptions like SealedSecrets.\n\n")
		fmt.Fprintf(os.Stderr, "Exit codes:\n")
		fmt.Fprintf(os.Stderr, "  0 - No sensitive files detected\n")
		fmt.Fprintf(os.Stderr, "  1 - Sensitive files detected\n")
		fmt.Fprintf(os.Stderr, "  2 - Invalid usage or system error\n\n")
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
	}
	flag.Parse()

	guard, err := NewSensitiveFilesGuard()
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(2)
	}

	if *listPatterns {
		fmt.Println("Sensitive Patterns:")
		for _, pattern := range sensitivePatternStrings {
			fmt.Printf("  %s\n", pattern)
		}
		fmt.Println("\nIgnore Patterns:")
		for _, pattern := range ignorePatternStrings {
			fmt.Printf("  %s\n", pattern)
		}
		os.Exit(0)
	}

	files, err := getGitFiles()
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(2)
	}

	matches := guard.Check(files)

	if len(matches) > 0 {
		fmt.Println("❌ Forbidden sensitive files detected:")
		for _, match := range matches {
			fmt.Println(match)
		}
		os.Exit(1)
	}

	fmt.Println("✅ Sensitive file check passed")
	os.Exit(0)
}
