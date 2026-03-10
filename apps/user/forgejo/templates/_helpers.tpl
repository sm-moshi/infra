{{/*
Override the upstream gitea.image helper so that:
  1.  The image ref is always  registry/repository:tag  (no -rootless suffix).
      Our Harbor image is already built FROM the rootless upstream variant,
      so the suffix is wrong — but we still need  image.rootless: true  for
      the chart's init-script selection.
  2.  argocd-image-updater can round-trip the tag it writes to
      forgejo.image.tag without fullOverride masking it.
*/}}
{{- define "gitea.image" -}}
{{- if .Values.image.registry -}}{{ .Values.image.registry }}/{{- end -}}
{{- .Values.image.repository -}}:{{- .Values.image.tag -}}
{{- end -}}
