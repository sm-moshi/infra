package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

// Issue represents a single idempotency issue found in a playbook
type Issue struct {
	Severity   string `json:"severity"`
	Location   string `json:"location"`
	Message    string `json:"message"`
	Suggestion string `json:"suggestion,omitempty"`
}

// IdempotencyChecker checks Ansible playbooks for idempotency issues
type IdempotencyChecker struct {
	strict bool
	issues []Issue
}

var (
	commandModules = []string{
		"command",
		"shell",
		"ansible.builtin.command",
		"ansible.builtin.shell",
	}

	secretModules = []string{
		"user",
		"ansible.builtin.user",
		"mysql_user",
		"community.mysql.mysql_user",
		"postgresql_user",
		"community.postgresql.postgresql_user",
	}

	secretKeywords = []string{
		"password", "token", "secret", "key", "credential", "api_key",
	}

	shortModuleNames = []string{
		"command", "shell", "copy", "template", "service", "file",
	}
)

func NewIdempotencyChecker(strict bool) *IdempotencyChecker {
	return &IdempotencyChecker{
		strict: strict,
		issues: []Issue{},
	}
}

func (ic *IdempotencyChecker) CheckPlaybook(playbookPath string) []Issue {
	ic.issues = []Issue{}

	data, err := os.ReadFile(playbookPath)
	if err != nil {
		return []Issue{{
			Severity: "error",
			Message:  fmt.Sprintf("Failed to read file: %v", err),
		}}
	}

	decoder := yaml.NewDecoder(strings.NewReader(string(data)))
	hasPlays := false

	for {
		var doc interface{}
		if err := decoder.Decode(&doc); err != nil {
			if err == io.EOF {
				break
			}
			return []Issue{{
				Severity: "error",
				Message:  fmt.Sprintf("Failed to parse YAML: %v", err),
			}}
		}

		if doc == nil {
			continue
		}

		plays := extractPlays(doc)
		if len(plays) == 0 {
			continue
		}
		hasPlays = true

		// Check each play
		for playIdx, play := range plays {
			// Check tasks
			if tasks, ok := play["tasks"].([]interface{}); ok {
				ic.checkTasks(tasks, fmt.Sprintf("play[%d].tasks", playIdx))
			}

			// Check handlers
			if handlers, ok := play["handlers"].([]interface{}); ok {
				ic.checkTasks(handlers, fmt.Sprintf("play[%d].handlers", playIdx))
			}

			// Check pre_tasks
			if preTasks, ok := play["pre_tasks"].([]interface{}); ok {
				ic.checkTasks(preTasks, fmt.Sprintf("play[%d].pre_tasks", playIdx))
			}

			// Check post_tasks
			if postTasks, ok := play["post_tasks"].([]interface{}); ok {
				ic.checkTasks(postTasks, fmt.Sprintf("play[%d].post_tasks", playIdx))
			}
		}
	}

	if !hasPlays {
		return []Issue{}
	}

	return ic.issues
}

func extractPlays(doc interface{}) []map[string]interface{} {
	plays := []map[string]interface{}{}

	switch v := doc.(type) {
	case []interface{}:
		for _, item := range v {
			if play, ok := item.(map[string]interface{}); ok {
				plays = append(plays, play)
			}
		}
	case map[string]interface{}:
		plays = append(plays, v)
	}

	return plays
}

func (ic *IdempotencyChecker) checkTasks(tasks []interface{}, location string) {
	for taskIdx, taskRaw := range tasks {
		task, ok := taskRaw.(map[string]interface{})
		if !ok {
			continue
		}

		taskLocation := fmt.Sprintf("%s[%d]", location, taskIdx)

		// Check for name
		ic.checkTaskName(task, taskLocation)

		// Check for command/shell issues
		ic.checkCommandShell(task, taskLocation)

		// Check for secret handling
		ic.checkSecrets(task, taskLocation)

		// Check for deprecated short names
		ic.checkModuleNames(task, taskLocation)

		// Recursively check blocks
		if block, ok := task["block"].([]interface{}); ok {
			ic.checkTasks(block, fmt.Sprintf("%s.block", taskLocation))
		}
		if rescue, ok := task["rescue"].([]interface{}); ok {
			ic.checkTasks(rescue, fmt.Sprintf("%s.rescue", taskLocation))
		}
		if always, ok := task["always"].([]interface{}); ok {
			ic.checkTasks(always, fmt.Sprintf("%s.always", taskLocation))
		}
	}
}

func (ic *IdempotencyChecker) checkTaskName(task map[string]interface{}, location string) {
	if _, hasName := task["name"]; !hasName {
		if _, hasInclude := task["include_tasks"]; hasInclude {
			return
		}
		if _, hasImport := task["import_tasks"]; hasImport {
			return
		}

		ic.issues = append(ic.issues, Issue{
			Severity:   "warning",
			Location:   location,
			Message:    "Task missing name attribute",
			Suggestion: "Add name: field to describe what this task does",
		})
	}
}

func (ic *IdempotencyChecker) checkCommandShell(task map[string]interface{}, location string) {
	moduleName, moduleArgs := ic.getCommandModule(task)
	if moduleName == "" {
		return
	}

	taskName := "unnamed task"
	if name, ok := task["name"].(string); ok {
		taskName = name
	}

	ic.checkChangedWhen(task, taskName, location)
	ic.checkShellPipefail(moduleName, moduleArgs, location)
	ic.checkCommandShellFeatures(moduleName, moduleArgs, location)
}

func (ic *IdempotencyChecker) getCommandModule(task map[string]interface{}) (string, interface{}) {
	for key, value := range task {
		for _, cmdModule := range commandModules {
			if key == cmdModule {
				return key, value
			}
		}
	}
	return "", nil
}

func (ic *IdempotencyChecker) checkChangedWhen(task map[string]interface{}, taskName, location string) {
	if _, hasChangedWhen := task["changed_when"]; hasChangedWhen {
		return
	}

	if _, hasRegister := task["register"]; !hasRegister {
		ic.issues = append(ic.issues, Issue{
			Severity:   "warning",
			Location:   location,
			Message:    "Command/shell task without changed_when or register",
			Suggestion: "Add changed_when: and register: for proper idempotency",
		})
		return
	}

	if ic.isCheckTask(taskName) {
		if ic.strict {
			ic.issues = append(ic.issues, Issue{
				Severity:   "info",
				Location:   location,
				Message:    "Command/shell task without changed_when",
				Suggestion: "Add changed_when: false if this is a read-only check",
			})
		}
		return
	}

	ic.issues = append(ic.issues, Issue{
		Severity:   "warning",
		Location:   location,
		Message:    "Command/shell task without changed_when",
		Suggestion: "Add changed_when: to control when task reports as changed",
	})
}

func (ic *IdempotencyChecker) isCheckTask(taskName string) bool {
	checkWords := []string{"check", "verify", "test", "get", "find"}
	nameLower := strings.ToLower(taskName)
	for _, word := range checkWords {
		if strings.Contains(nameLower, word) {
			return true
		}
	}
	return false
}

func (ic *IdempotencyChecker) checkShellPipefail(moduleName string, moduleArgs interface{}, location string) {
	if !strings.Contains(moduleName, "shell") {
		return
	}

	argsStr, ok := moduleArgs.(string)
	if !ok {
		return
	}

	if !strings.Contains(argsStr, "|") && !strings.Contains(argsStr, ">") {
		return
	}

	if strings.Contains(argsStr, "set -euo pipefail") || strings.Contains(argsStr, "set -o pipefail") {
		return
	}

	ic.issues = append(ic.issues, Issue{
		Severity:   "warning",
		Location:   location,
		Message:    `Shell task with pipes missing "set -euo pipefail"`,
		Suggestion: `Add "set -euo pipefail" at the start of shell script`,
	})
}

func (ic *IdempotencyChecker) checkCommandShellFeatures(moduleName string, moduleArgs interface{}, location string) {
	if !strings.Contains(moduleName, "command") {
		return
	}

	argsStr, ok := moduleArgs.(string)
	if !ok {
		return
	}

	shellChars := []string{"|", ">", "<", "&", ";", "$"}
	hasShellFeature := false
	for _, char := range shellChars {
		if strings.Contains(argsStr, char) {
			hasShellFeature = true
			break
		}
	}

	if !hasShellFeature {
		return
	}

	ic.issues = append(ic.issues, Issue{
		Severity:   "info",
		Location:   location,
		Message:    "Command module used with shell features",
		Suggestion: "Consider using shell module instead (requires pipes, redirects, etc.)",
	})
}

func (ic *IdempotencyChecker) checkSecrets(task map[string]interface{}, location string) {
	// Check if using a secret module
	hasSecretModule := false
	for key := range task {
		for _, secretModule := range secretModules {
			if key == secretModule {
				hasSecretModule = true
				break
			}
		}
		if hasSecretModule {
			break
		}
	}

	// Check task text for secret keywords
	taskText := strings.ToLower(fmt.Sprintf("%v", task))
	hasSecretKeyword := false
	for _, keyword := range secretKeywords {
		if strings.Contains(taskText, keyword) {
			hasSecretKeyword = true
			break
		}
	}

	if hasSecretModule || hasSecretKeyword {
		if !isTruthyNoLog(task["no_log"]) {
			ic.issues = append(ic.issues, Issue{
				Severity:   "warning",
				Location:   location,
				Message:    "Task may handle secrets without no_log",
				Suggestion: "Add no_log: true to prevent secret leakage",
			})
		}
	}
}

func isTruthyNoLog(value interface{}) bool {
	switch v := value.(type) {
	case bool:
		return v
	case string:
		normalized := strings.TrimSpace(strings.ToLower(v))
		if normalized == "" {
			return false
		}
		return normalized == "true" || normalized == "yes" || normalized == "on" || normalized == "1"
	default:
		return false
	}
}

func (ic *IdempotencyChecker) checkModuleNames(task map[string]interface{}, location string) {
	for key := range task {
		for _, shortName := range shortModuleNames {
			if key == shortName {
				ic.issues = append(ic.issues, Issue{
					Severity:   "info",
					Location:   location,
					Message:    "Short module name used",
					Suggestion: fmt.Sprintf("Use ansible.builtin.%s for clarity", shortName),
				})
			}
		}
	}
}

func printIssues(playbookPath string, issues []Issue) {
	if len(issues) == 0 {
		return
	}

	fmt.Printf("\nPlaybook: %s\n", playbookPath)
	fmt.Println(strings.Repeat("=", 70))

	errors := []Issue{}
	warnings := []Issue{}
	info := []Issue{}

	for _, issue := range issues {
		switch issue.Severity {
		case "error":
			errors = append(errors, issue)
		case "warning":
			warnings = append(warnings, issue)
		case "info":
			info = append(info, issue)
		}
	}

	severities := []struct {
		name  string
		items []Issue
	}{
		{"ERROR", errors},
		{"WARNING", warnings},
		{"INFO", info},
	}

	for _, sev := range severities {
		if len(sev.items) == 0 {
			continue
		}

		fmt.Printf("\n%s (%d):\n", sev.name, len(sev.items))
		for _, issue := range sev.items {
			fmt.Printf("  Location: %s\n", issue.Location)
			fmt.Printf("  Issue: %s\n", issue.Message)
			if issue.Suggestion != "" {
				fmt.Printf("  Suggestion: %s\n", issue.Suggestion)
			}
			fmt.Println()
		}
	}
}

func main() {
	strict := flag.Bool("strict", false, "Include informational issues")
	summary := flag.Bool("summary", false, "Show only summary, not individual issues")
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [options] <playbook.yml> [<playbook2.yml> ...]\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "\nCheck Ansible playbooks for common idempotency issues.\n\n")
		fmt.Fprintf(os.Stderr, "Detects:\n")
		fmt.Fprintf(os.Stderr, "- Command/shell tasks without changed_when\n")
		fmt.Fprintf(os.Stderr, "- Shell tasks without set -euo pipefail\n")
		fmt.Fprintf(os.Stderr, "- Tasks without no_log that may contain secrets\n")
		fmt.Fprintf(os.Stderr, "- Tasks missing name attribute\n")
		fmt.Fprintf(os.Stderr, "- Use of deprecated short module names\n\n")
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
	}
	flag.Parse()

	if flag.NArg() == 0 {
		flag.Usage()
		os.Exit(2)
	}

	playbookPaths := flag.Args()
	checker := NewIdempotencyChecker(*strict)
	allIssues := make(map[string][]Issue)
	totalIssues := 0

	for _, playbookPath := range playbookPaths {
		if _, err := os.Stat(playbookPath); os.IsNotExist(err) {
			fmt.Fprintf(os.Stderr, "ERROR: File not found: %s\n", playbookPath)
			continue
		}

		issues := checker.CheckPlaybook(playbookPath)
		allIssues[playbookPath] = issues
		totalIssues += len(issues)

		if !*summary {
			printIssues(playbookPath, issues)
		}
	}

	fmt.Println()
	fmt.Println(strings.Repeat("=", 70))
	fmt.Printf("Summary: Checked %d playbook(s)\n", len(playbookPaths))
	fmt.Printf("Total issues: %d\n", totalIssues)

	if totalIssues == 0 {
		fmt.Println("All playbooks look good.")
		os.Exit(0)
	}

	playbooksWithIssues := 0
	for _, issues := range allIssues {
		if len(issues) > 0 {
			playbooksWithIssues++
		}
	}

	fmt.Printf("Found issues in %d playbook(s).\n", playbooksWithIssues)
	os.Exit(1)
}
