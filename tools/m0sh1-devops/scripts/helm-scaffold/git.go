package main

import (
	"os/exec"
	"strings"
)

// detectGitOrigin attempts to detect git remote origin URL
func detectGitOrigin(repoPath string) string {
	cmd := exec.Command("git", "-C", repoPath, "remote", "get-url", "origin")
	output, err := cmd.Output()
	if err != nil {
		return ""
	}

	origin := strings.TrimSpace(string(output))
	return origin
}
