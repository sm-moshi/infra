"""Template strings for Helm chart scaffolding."""

from __future__ import annotations


def chart_yaml(name: str, version: str = "0.1.0", app_version: str = "0.1.0") -> str:
    """Generate Chart.yaml content."""
    return f"""apiVersion: v2
name: {name}
version: {version}
description: {name} wrapper chart
type: application
appVersion: "{app_version}"
"""


def values_yaml_wrapper() -> str:
    """Generate values.yaml for wrapper charts."""
    return """image:
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
"""


def values_yaml_simple() -> str:
    """Generate values.yaml for simple charts."""
    return """image:
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
"""


def deployment_yaml(name: str) -> str:
    """Generate deployment.yaml template."""
    return f"""apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{{{{{ .Release.Name }}}}}}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {name}
  template:
    metadata:
      labels:
        app: {name}
    spec:
      containers:
        - name: {name}
          image: "{{{{{{ .Values.image.repository }}}}}}:{{{{{{ .Values.image.tag }}}}}}"
          imagePullPolicy: {{{{{{ .Values.image.pullPolicy }}}}}}
          ports:
            - containerPort: {{{{{{ .Values.service.port }}}}}}
          env:
            {{{{{{- range $name, $value := .Values.env }}}}}}
            - name: {{{{{{ $name }}}}}}
              value: {{{{{{ $value | quote }}}}}}
            {{{{{{- end }}}}}}
          {{{{{{- if .Values.envFromSecret }}}}}}
          envFrom:
            - secretRef:
                name: {{{{{{ .Values.envFromSecret }}}}}}
          {{{{{{- end }}}}}}
"""


def service_yaml(name: str) -> str:
    """Generate service.yaml template."""
    return f"""apiVersion: v1
kind: Service
metadata:
  name: {{{{{{ .Release.Name }}}}}}
  namespace: {{{{{{ .Release.Namespace }}}}}}
  labels:
    app: {name}
{{{{{{- with .Values.service.annotations }}}}}}
  annotations:
    {{{{{{- toYaml . | nindent 4 }}}}}}
{{{{{{- end }}}}}}
spec:
  type: {{{{{{ .Values.service.type | default "ClusterIP" }}}}}}
  ports:
    - name: http
      port: {{{{{{ .Values.service.port }}}}}}
      targetPort: {{{{{{ .Values.service.port }}}}}}
      protocol: TCP
  selector:
    app: {name}
"""


def ingress_yaml() -> str:
    """Generate ingress.yaml template."""
    return """{{- if .Values.ingress.enabled }}
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
"""


def argocd_application_yaml(
    name: str,
    scope: str,
    repo_url: str,
    revision: str,
    source_path: str,
    dest_namespace: str,
) -> str:
    """Generate ArgoCD Application manifest."""
    return f"""apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {name}
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: apps-root
spec:
  project: default

  source:
    repoURL: {repo_url}
    targetRevision: {revision}
    path: {source_path}
    helm:
      releaseName: {name}
      valueFiles:
        - values.yaml

  destination:
    server: https://kubernetes.default.svc
    namespace: {dest_namespace}

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
"""
