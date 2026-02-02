package main

import (
	"os"
	"path/filepath"
)

const chartFile = "Chart.yaml"

// detectRepoType determines if repo is 'infra' or 'helm-charts'
func detectRepoType(repoPath string) string {
	// Check for infra repo structure
	appsDir := filepath.Join(repoPath, "apps")
	clusterDir := filepath.Join(repoPath, "cluster")
	if exists(appsDir) && exists(clusterDir) {
		return "infra"
	}

	// Check for helm-charts repo structure
	chartsDir := filepath.Join(repoPath, "charts")
	if exists(chartsDir) {
		return "helm-charts"
	}

	return "unknown"
}

// detectLayout determines chart layout within infra repo
func detectLayout(repoPath string) string {
	// Prefer root layout: apps/<scope>/<name>/Chart.yaml
	clusterCharts, _ := filepath.Glob(filepath.Join(repoPath, "apps", "cluster", "*", chartFile))
	userCharts, _ := filepath.Glob(filepath.Join(repoPath, "apps", "user", "*", chartFile))

	if len(clusterCharts) > 0 || len(userCharts) > 0 {
		return "root"
	}

	// Fallback to helm layout: apps/<scope>/<name>/helm/Chart.yaml
	clusterHelmCharts, _ := filepath.Glob(filepath.Join(repoPath, "apps", "cluster", "*", "helm", chartFile))
	userHelmCharts, _ := filepath.Glob(filepath.Join(repoPath, "apps", "user", "*", "helm", chartFile))

	if len(clusterHelmCharts) > 0 || len(userHelmCharts) > 0 {
		return "helm"
	}

	return "root"
}

// exists checks if a path exists
func exists(path string) bool {
	_, err := os.Stat(path)
	return !os.IsNotExist(err)
}
