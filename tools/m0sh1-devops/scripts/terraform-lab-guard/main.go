package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
)

type Issue struct {
	Severity string `json:"severity"`
	Message  string `json:"message"`
	Path     string `json:"path,omitempty"`
}

const (
	providersTF = "providers.tf"
	versionsTF  = "versions.tf"
)

var skipTerraformDirs = map[string]bool{
	".git":              true,
	".terraform":        true,
	".terragrunt-cache": true,
	"node_modules":      true,
	".cache":            true,
}

func shouldSkipTerraformDir(name string) bool {
	return skipTerraformDirs[name]
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

	terraformDir := filepath.Join(repoPath, "terraform")
	if _, err := os.Stat(terraformDir); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "terraform/ not found in %s\n", repoPath)
		os.Exit(2)
	}

	envsDir := filepath.Join(terraformDir, "envs")
	labDir := filepath.Join(envsDir, "lab")

	issues := []Issue{}

	// Validate environment structure
	issues = append(issues, validateEnvironmentStructure(envsDir)...)

	// Validate required files
	issues = append(issues, validateRequiredFiles(labDir)...)

	// Validate provider blocks
	issues = append(issues, validateProviderBlocks(terraformDir, labDir)...)

	// Validate module sources
	issues = append(issues, validateModuleSources(labDir)...)

	// Output results
	formatOutput(issues, repoPath, *asJSON)

	// Determine exit code
	os.Exit(getExitCode(issues, *strict))
}

func validateEnvironmentStructure(envsDir string) []Issue {
	var issues []Issue

	if _, err := os.Stat(envsDir); os.IsNotExist(err) {
		issues = append(issues, Issue{
			Severity: "error",
			Message:  "terraform/envs directory missing",
			Path:     envsDir,
		})
		return issues
	}

	entries, err := os.ReadDir(envsDir)
	if err != nil {
		return issues
	}

	for _, entry := range entries {
		if entry.IsDir() && entry.Name() != "lab" {
			issues = append(issues, Issue{
				Severity: "error",
				Message:  fmt.Sprintf("Unexpected terraform env: %s", entry.Name()),
				Path:     filepath.Join(envsDir, entry.Name()),
			})
		}
	}

	return issues
}

func validateRequiredFiles(labDir string) []Issue {
	var issues []Issue
	requiredFiles := []string{providersTF, versionsTF, "defaults.auto.tfvars", "secrets.auto.tfvars"}

	for _, filename := range requiredFiles {
		filePath := filepath.Join(labDir, filename)
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			issues = append(issues, Issue{
				Severity: "error",
				Message:  fmt.Sprintf("Missing %s in terraform/envs/lab", filename),
				Path:     filePath,
			})
		}
	}

	return issues
}

func validateProviderBlocks(terraformDir, labDir string) []Issue {
	var issues []Issue

	providerRegex := regexp.MustCompile(`(?m)^\s*provider\s+"`)
	backendRegex := regexp.MustCompile(`(?m)^\s*backend\s+"`)

	err := filepath.Walk(terraformDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() {
			if shouldSkipTerraformDir(info.Name()) {
				return filepath.SkipDir
			}
			return nil
		}

		if filepath.Ext(path) != ".tf" {
			return nil
		}

		// Skip files in lab directory
		if isParent(labDir, path) {
			return nil
		}

		content, err := os.ReadFile(path)
		if err != nil {
			return nil
		}

		text := string(content)

		if providerRegex.MatchString(text) {
			issues = append(issues, Issue{
				Severity: "error",
				Message:  "provider block outside envs/lab",
				Path:     path,
			})
		}

		if backendRegex.MatchString(text) {
			issues = append(issues, Issue{
				Severity: "error",
				Message:  "backend block outside envs/lab",
				Path:     path,
			})
		}

		return nil
	})

	if err != nil {
		fmt.Fprintf(os.Stderr, "Warning: error walking terraform directory: %v\n", err)
	}

	return issues
}

func validateModuleSources(labDir string) []Issue {
	var issues []Issue

	sourceRegex := regexp.MustCompile(`(?m)^\s*source\s*=\s*"([^"]+)"`)

	err := filepath.Walk(labDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() {
			if shouldSkipTerraformDir(info.Name()) {
				return filepath.SkipDir
			}
			return nil
		}

		if filepath.Ext(path) != ".tf" {
			return nil
		}

		// Skip special files
		if filepath.Base(path) == versionsTF || filepath.Base(path) == providersTF {
			return nil
		}

		content, err := os.ReadFile(path)
		if err != nil {
			return nil
		}

		text := string(content)
		matches := sourceRegex.FindAllStringSubmatch(text, -1)

		for _, match := range matches {
			if len(match) < 2 {
				continue
			}

			source := match[1]
			if !isModulePath(source) {
				issues = append(issues, Issue{
					Severity: "warning",
					Message:  fmt.Sprintf("Module source not under terraform/modules: %s", source),
					Path:     path,
				})
			}
		}

		return nil
	})

	if err != nil {
		fmt.Fprintf(os.Stderr, "Warning: error walking lab directory: %v\n", err)
	}

	return issues
}

func isModulePath(source string) bool {
	return len(source) >= 10 && (source[:10] == "./modules/" ||
		source[:11] == "../modules/" ||
		source[:14] == "../../modules/")
}

func isParent(parent, child string) bool {
	rel, err := filepath.Rel(parent, child)
	if err != nil {
		return false
	}
	return len(rel) > 0 && rel[0] != '.' && rel[:2] != ".."
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
		fmt.Println("✅ Terraform lab checks passed")
	} else {
		fmt.Println("Terraform lab issues:")
		for _, issue := range issues {
			loc := ""
			if issue.Path != "" {
				loc = fmt.Sprintf(" (%s)", issue.Path)
			}
			fmt.Printf("- [%s] %s%s\n", issue.Severity, issue.Message, loc)
		}
	}

	fmt.Println("\nStandard workflow:")
	fmt.Println("export $(cat terraform/op.env | xargs)")
	fmt.Println("terraform -chdir=terraform fmt -recursive")
	fmt.Println("terraform -chdir=terraform/envs/lab init -backend=false")
	fmt.Println("terraform -chdir=terraform/envs/lab validate")
	fmt.Println("terraform -chdir=terraform/envs/lab plan -var-file=defaults.auto.tfvars -var-file=secrets.auto.tfvars")
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
