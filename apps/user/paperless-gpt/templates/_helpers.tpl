{{- define "paperless-gpt.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "paperless-gpt.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "paperless-gpt.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "paperless-gpt.labels" -}}
app.kubernetes.io/name: {{ include "paperless-gpt.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "paperless-gpt.selectorLabels" -}}
app.kubernetes.io/name: {{ include "paperless-gpt.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
