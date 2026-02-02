package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
)

func main() {
	// Command-line flags
	repo := flag.String("repo", "", "Path to infra or helm-charts repo (required)")
	name := flag.String("name", "", "Chart/app name (required)")
	repoType := flag.String("repo-type", "auto", "Repository type: infra, helm-charts, auto")
	scope := flag.String("scope", "", "Scope for infra repo: cluster or user")
	layout := flag.String("layout", "detect", "Chart layout: detect, helm, root")
	argoCD := flag.Bool("argocd", false, "Create ArgoCD Application stub")
	disabled := flag.Bool("disabled", false, "Place Application under disabled/")
	destNamespace := flag.String("dest-namespace", "", "Destination namespace for ArgoCD Application")
	repoURL := flag.String("repo-url", "", "Override repoURL in ArgoCD Application")
	revision := flag.String("revision", "main", "Git revision for ArgoCD Application")
	force := flag.Bool("force", false, "Overwrite existing files")

	flag.Parse()

	// Validate required arguments
	if *repo == "" || *name == "" {
		fmt.Fprintln(os.Stderr, "Error: --repo and --name are required")
		flag.Usage()
		os.Exit(2)
	}

	validRepoTypes := map[string]bool{"auto": true, "infra": true, "helm-charts": true}
	if !validRepoTypes[*repoType] {
		fmt.Fprintln(os.Stderr, "Error: --repo-type must be one of auto, infra, helm-charts")
		os.Exit(2)
	}

	// Resolve repo path
	repoPath, err := filepath.Abs(*repo)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error resolving repo path: %v\n", err)
		os.Exit(2)
	}

	if _, err := os.Stat(repoPath); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Repo path does not exist: %s\n", repoPath)
		os.Exit(2)
	}

	// Detect repo type
	detectedType := *repoType
	if detectedType == "auto" {
		detectedType = detectRepoType(repoPath)
	}

	// Handle infra repo
	if detectedType == "infra" {
		if *scope == "" {
			fmt.Fprintln(os.Stderr, "Error: --scope is required for infra repo")
			os.Exit(2)
		}
		if *scope != "cluster" && *scope != "user" {
			fmt.Fprintln(os.Stderr, "Error: --scope must be cluster or user")
			os.Exit(2)
		}

		if *layout != "detect" && *layout != "helm" && *layout != "root" {
			fmt.Fprintln(os.Stderr, "Error: --layout must be detect, helm, or root")
			os.Exit(2)
		}

		detectedLayout := *layout
		if detectedLayout == "detect" {
			detectedLayout = detectLayout(repoPath)
		}

		if err := scaffoldWrapperChart(scaffoldOpts{
			repo:          repoPath,
			name:          *name,
			scope:         *scope,
			layout:        detectedLayout,
			argoCD:        *argoCD,
			disabled:      *disabled,
			destNamespace: *destNamespace,
			repoURL:       *repoURL,
			revision:      *revision,
			force:         *force,
		}); err != nil {
			fmt.Fprintf(os.Stderr, "Error scaffolding wrapper chart: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("✅ Scaffolded wrapper chart in %s\n", repoPath)
		return
	}

	// Handle helm-charts repo
	if detectedType == "helm-charts" {
		if err := scaffoldChart(repoPath, *name, *force); err != nil {
			fmt.Fprintf(os.Stderr, "Error scaffolding chart: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("✅ Scaffolded chart in %s\n", repoPath)
		return
	}

	fmt.Fprintln(os.Stderr, "Could not detect repo type; use --repo-type")
	os.Exit(2)
}
