package main

import (
	"fmt"
)

// chartYAML generates Chart.yaml content
func chartYAML(name string) string {
	return fmt.Sprintf(`apiVersion: v2
name: %s
version: 0.1.0
description: %s wrapper chart
type: application
appVersion: "0.1.0"
`, name, name)
}

// valuesYAMLWrapper generates values.yaml for wrapper charts
func valuesYAMLWrapper() string {
	return `image:
  repository: example/image
  tag: "0.1.0"
  pullPolicy: IfNotPresent

service:
  port: 8080

envFromSecret: ""

env: {}

ingress:
  enabled: false
  className: traefik
  annotations: {}
  hosts:
    - host: example.m0sh1.cc
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 256Mi
`
}

// valuesYAMLSimple generates values.yaml for simple charts
func valuesYAMLSimple() string {
	return `image:
  repository: example/image
  tag: "0.1.0"
  pullPolicy: IfNotPresent

service:
  port: 8080

envFromSecret: ""

env: {}

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 256Mi
`
}

// deploymentYAML generates deployment.yaml template
func deploymentYAML(name string) string {
	return fmt.Sprintf(`apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: %s
  template:
    metadata:
      labels:
        app: %s
    spec:
      containers:
        - name: %s
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.port }}
          env:
            {{- range $name, $value := .Values.env }}
            - name: {{ $name }}
              value: {{ $value | quote }}
            {{- end }}
          {{- if .Values.envFromSecret }}
          envFrom:
            - secretRef:
                name: {{ .Values.envFromSecret }}
          {{- end }}
`, name, name, name)
}

// serviceYAML generates service.yaml template
func serviceYAML(name string) string {
	return fmt.Sprintf(`apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    app: %s
{{- with .Values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
{{- end }}
spec:
  type: {{ .Values.service.type | default "ClusterIP" }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.port }}
      protocol: TCP
  selector:
    app: %s
`, name, name)
}

// ingressYAML generates ingress.yaml template
func ingressYAML() string {
	return `{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
{{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
{{- end }}
spec:
  ingressClassName: {{ .Values.ingress.className | default "traefik" | quote }}
  rules:
  {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
        {{- range .paths }}
          - path: {{ .path | quote }}
            pathType: {{ .pathType | default "Prefix" | quote }}
            backend:
              service:
                name: {{ $.Release.Name }}
                port:
                  number: {{ $.Values.service.port }}
        {{- end }}
  {{- end }}
{{- with .Values.ingress.tls }}
  tls:
  {{- range . }}
    - secretName: {{ .secretName }}
      hosts:
      {{- range .hosts }}
        - {{ . }}
      {{- end }}
  {{- end }}
{{- end }}
{{- end }}
`
}

// argoCDApplicationYAML generates ArgoCD Application manifest
func argoCDApplicationYAML(name, scope, repoURL, revision, sourcePath, destNamespace string) string {
	return fmt.Sprintf(`apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: %s
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: apps-root
spec:
  project: default

  source:
    repoURL: %s
    targetRevision: %s
    path: %s
    helm:
      releaseName: %s
      valueFiles:
        - values.yaml

  destination:
    server: https://kubernetes.default.svc
    namespace: %s

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
`, name, repoURL, revision, sourcePath, name, destNamespace)
}
