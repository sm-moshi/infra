{{- define "cluster-network-policies.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cluster-network-policies.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" (include "cluster-network-policies.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "cluster-network-policies.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cluster-network-policies.commonLabels" -}}
helm.sh/chart: {{ include "cluster-network-policies.chart" . }}
app.kubernetes.io/name: {{ include "cluster-network-policies.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "cluster-network-policies.policyName" -}}
{{- $namespace := .namespace -}}
{{- $suffix := .suffix -}}
{{- printf "%s-%s" $namespace $suffix | lower | replace "_" "-" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
