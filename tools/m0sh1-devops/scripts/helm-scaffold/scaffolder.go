package main

import (
	"fmt"
	"os"
	"path/filepath"
)

type scaffoldOpts struct {
	repo          string
	name          string
	scope         string
	layout        string
	argoCD        bool
	disabled      bool
	destNamespace string
	repoURL       string
	revision      string
	force         bool
}

// scaffoldWrapperChart creates a wrapper chart for infra repo
func scaffoldWrapperChart(opts scaffoldOpts) error {
	baseDir := filepath.Join(opts.repo, "apps", opts.scope, opts.name)

	var chartDir string
	if opts.layout == "helm" {
		chartDir = filepath.Join(baseDir, "helm")
	} else {
		chartDir = baseDir
	}

	templatesDir := filepath.Join(chartDir, "templates")
	if err := os.MkdirAll(templatesDir, 0755); err != nil {
		return fmt.Errorf("creating templates directory: %w", err)
	}

	// Write chart files
	files := map[string]string{
		filepath.Join(chartDir, chartFile):                       chartYAML(opts.name),
		filepath.Join(chartDir, "values.yaml"):                   valuesYAMLWrapper(),
		filepath.Join(templatesDir, "deployment.yaml"):           deploymentYAML(opts.name),
		filepath.Join(templatesDir, "service.yaml"):              serviceYAML(opts.name),
		filepath.Join(templatesDir, "ingress.yaml"):              ingressYAML(),
	}

	for path, content := range files {
		if err := writeFile(path, content, opts.force); err != nil {
			return err
		}
	}

	// Create ArgoCD Application if requested
	if opts.argoCD {
		appBase := filepath.Join(opts.repo, "argocd", "apps", opts.scope)
		if opts.disabled {
			appBase = filepath.Join(opts.repo, "argocd", "disabled", opts.scope)
		}

		if err := os.MkdirAll(appBase, 0755); err != nil {
			return fmt.Errorf("creating argocd directory: %w", err)
		}

		appPath := filepath.Join(appBase, fmt.Sprintf("%s.yaml", opts.name))

		repoURL := opts.repoURL
		if repoURL == "" {
			repoURL = detectGitOrigin(opts.repo)
			if repoURL == "" {
				repoURL = "REPO_URL"
			}
		}

		destNS := opts.destNamespace
		if destNS == "" {
			if opts.scope == "user" {
				destNS = "apps"
			} else {
				destNS = opts.name
			}
		}

		sourcePath := fmt.Sprintf("apps/%s/%s", opts.scope, opts.name)
		if opts.layout == "helm" {
			sourcePath = sourcePath + "/helm"
		}

		appYAML := argoCDApplicationYAML(opts.name, opts.scope, repoURL, opts.revision, sourcePath, destNS)
		if err := writeFile(appPath, appYAML, opts.force); err != nil {
			return err
		}
	}

	return nil
}

// scaffoldChart creates a standalone chart for helm-charts repo
func scaffoldChart(repo, name string, force bool) error {
	chartDir := filepath.Join(repo, "charts", name)
	templatesDir := filepath.Join(chartDir, "templates")

	if err := os.MkdirAll(templatesDir, 0755); err != nil {
		return fmt.Errorf("creating templates directory: %w", err)
	}

	files := map[string]string{
		filepath.Join(chartDir, chartFile):             chartYAML(name),
		filepath.Join(chartDir, "values.yaml"):         valuesYAMLSimple(),
		filepath.Join(templatesDir, "deployment.yaml"): deploymentYAML(name),
		filepath.Join(templatesDir, "service.yaml"):    serviceYAML(name),
	}

	for path, content := range files {
		if err := writeFile(path, content, force); err != nil {
			return err
		}
	}

	return nil
}

// writeFile writes content to a file, optionally overwriting
func writeFile(path, content string, force bool) error {
	if !force {
		if _, err := os.Stat(path); !os.IsNotExist(err) {
			return fmt.Errorf("file exists: %s (use --force to overwrite)", path)
		}
	}

	return os.WriteFile(path, []byte(content), 0644)
}
