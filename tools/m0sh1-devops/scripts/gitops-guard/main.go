package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"
)

type Issue struct {
	Severity string `json:"severity"`
	Message  string `json:"message"`
	Path     string `json:"path,omitempty"`
}

var skipDirs = map[string]bool{
	".git":              true,
	".venv":             true,
	".terraform":        true,
	".terragrunt-cache": true,
	"node_modules":      true,
	".cache":            true,
}

func shouldSkipDir(name string) bool {
	return skipDirs[name]
}

func main() {
	repo := flag.String("repo", "", "Path to infra repo (required)")
	asJSON := flag.Bool("json", false, "Output JSON")
	strict := flag.Bool("strict", false, "Fail on warnings")

	flag.Parse()

	if *repo == "" {
		fmt.Fprintln(os.Stderr, "Error: --repo is required")
		flag.Usage()
		os.Exit(2)
	}

	repoPath, err := filepath.Abs(*repo)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error resolving repo path: %v\n", err)
		os.Exit(2)
	}

	if _, err := os.Stat(repoPath); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Repo path does not exist: %s\n", repoPath)
		os.Exit(2)
	}

	issues := []Issue{}
	issues = append(issues, checkAppsLayout(repoPath)...)
	issues = append(issues, checkEnvOverlays(repoPath)...)
	issues = append(issues, scanYAML(repoPath)...)

	formatOutput(issues, repoPath, *asJSON)
	os.Exit(getExitCode(issues, *strict))
}

func checkAppsLayout(repoPath string) []Issue {
	var issues []Issue
	appsDir := filepath.Join(repoPath, "apps")

	if _, err := os.Stat(appsDir); os.IsNotExist(err) {
		return issues
	}

	allowed := map[string]bool{"cluster": true, "user": true, "argocd": true}

	entries, err := os.ReadDir(appsDir)
	if err != nil {
		return issues
	}

	for _, entry := range entries {
		if entry.IsDir() && !allowed[entry.Name()] {
			issues = append(issues, Issue{
				Severity: "error",
				Message:  fmt.Sprintf("Unexpected apps/ child directory: %s", entry.Name()),
				Path:     filepath.Join(appsDir, entry.Name()),
			})
		}
	}

	return issues
}

func checkEnvOverlays(repoPath string) []Issue {
	var issues []Issue
	envRoot := filepath.Join(repoPath, "cluster", "environments")

	if _, err := os.Stat(envRoot); os.IsNotExist(err) {
		return issues
	}

	entries, err := os.ReadDir(envRoot)
	if err != nil {
		return issues
	}

	for _, entry := range entries {
		if entry.IsDir() && entry.Name() != "lab" {
			issues = append(issues, Issue{
				Severity: "error",
				Message:  fmt.Sprintf("Unexpected environment overlay: %s", entry.Name()),
				Path:     filepath.Join(envRoot, entry.Name()),
			})
		}
	}

	return issues
}

func scanYAML(repoPath string) []Issue {
	var issues []Issue

	err := filepath.Walk(repoPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() {
			if shouldSkipDir(info.Name()) {
				return filepath.SkipDir
			}
			return nil
		}

		if !strings.HasSuffix(path, ".yaml") && !strings.HasSuffix(path, ".yml") {
			return nil
		}

		// Skip bootstrap directory
		if strings.Contains(path, "/bootstrap/") {
			return nil
		}

		content, err := os.ReadFile(path)
		if err != nil {
			return nil
		}

		issues = append(issues, checkYAMLFile(path, string(content))...)
		return nil
	})

	if err != nil {
		fmt.Fprintf(os.Stderr, "Warning: error walking repo: %v\n", err)
	}

	return issues
}

func checkYAMLFile(path, text string) []Issue {
	var issues []Issue

	if strings.TrimSpace(text) == "" {
		return issues
	}

	// Check for plain Secrets (document-aware)
	issues = append(issues, checkPlainSecrets(path, text)...)

	// Check for skip-reconcile annotation
	if strings.Contains(text, "argocd.argoproj.io/skip-reconcile") {
		issues = append(issues, Issue{
			Severity: "warning",
			Message:  "skip-reconcile annotation present (recovery-only)",
			Path:     path,
		})
	}

	// Check ArgoCD Applications
	appRegex := regexp.MustCompile(`(?m)^kind:\s*Application(Set)?\b`)
	if appRegex.MatchString(text) {
		// Check path
		if !isArgoCDApplicationPath(path) {
			issues = append(issues, Issue{
				Severity: "error",
				Message:  "ArgoCD Application manifest outside argocd/apps/ or argocd/disabled/",
				Path:     path,
			})
		}

		// Check for required label
		labelRegex := regexp.MustCompile(`(?m)^\s*app\.kubernetes\.io/part-of:\s*apps-root\b`)
		if !labelRegex.MatchString(text) {
			issues = append(issues, Issue{
				Severity: "error",
				Message:  "ArgoCD Application missing app.kubernetes.io/part-of: apps-root label",
				Path:     path,
			})
		}

		// Check for direct chart usage
		chartRegex := regexp.MustCompile(`(?m)^\s*chart:\s*\S+`)
		if chartRegex.MatchString(text) {
			issues = append(issues, Issue{
				Severity: "error",
				Message:  "ArgoCD Application uses chart: (direct Helm repo); use wrapper chart path",
				Path:     path,
			})
		}
	}

	return issues
}

func checkPlainSecrets(path, text string) []Issue {
	issues := []Issue{}

	decoder := yaml.NewDecoder(strings.NewReader(text))
	parsed := false
	for {
		var doc interface{}
		err := decoder.Decode(&doc)
		if err == io.EOF {
			break
		}
		if err != nil {
			parsed = false
			break
		}
		if doc == nil {
			continue
		}
		parsed = true
		if docMap, ok := doc.(map[string]interface{}); ok {
			if kind, ok := docMap["kind"].(string); ok && kind == "Secret" {
				issues = append(issues, Issue{
					Severity: "error",
					Message:  "Plain Secret found; use SealedSecrets",
					Path:     path,
				})
			}
		}
	}

	if parsed || len(issues) > 0 {
		return issues
	}

	// Fallback: regex scan if YAML parsing failed
	secretRegex := regexp.MustCompile(`(?m)^kind:\s*Secret\b`)
	sealedSecretRegex := regexp.MustCompile(`(?m)^kind:\s*SealedSecret\b`)
	if secretRegex.MatchString(text) && !sealedSecretRegex.MatchString(text) {
		issues = append(issues, Issue{
			Severity: "error",
			Message:  "Plain Secret found; use SealedSecrets",
			Path:     path,
		})
	}

	return issues
}

func isArgoCDApplicationPath(path string) bool {
	// Check if path contains argocd/apps or argocd/disabled
	return strings.Contains(path, "/argocd/apps/") ||
		strings.Contains(path, "/argocd/disabled/")
}

func formatOutput(issues []Issue, repo string, asJSON bool) {
	if asJSON {
		output := map[string]interface{}{
			"repo":   repo,
			"issues": issues,
		}
		data, _ := json.MarshalIndent(output, "", "  ")
		fmt.Println(string(data))
		return
	}

	if len(issues) == 0 {
		fmt.Println("✅ No GitOps issues detected")
		return
	}

	fmt.Println("GitOps issues:")
	for _, issue := range issues {
		loc := ""
		if issue.Path != "" {
			loc = fmt.Sprintf(" (%s)", issue.Path)
		}
		fmt.Printf("- [%s] %s%s\n", issue.Severity, issue.Message, loc)
	}
}

func getExitCode(issues []Issue, strict bool) int {
	hasError := false
	for _, issue := range issues {
		if issue.Severity == "error" {
			hasError = true
			break
		}
	}

	if hasError {
		return 1
	}

	if strict && len(issues) > 0 {
		return 1
	}

	return 0
}
