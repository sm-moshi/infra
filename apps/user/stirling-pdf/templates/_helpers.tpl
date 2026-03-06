{{- define "stirling-pdf.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "stirling-pdf.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "stirling-pdf.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "stirling-pdf.labels" -}}
app.kubernetes.io/name: {{ include "stirling-pdf.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "stirling-pdf.selectorLabels" -}}
app.kubernetes.io/name: {{ include "stirling-pdf.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
