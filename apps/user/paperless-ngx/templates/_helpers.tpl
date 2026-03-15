{{/*
Expand the name of the chart.
*/}}
{{- define "paperless-ngx.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "paperless-ngx.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "paperless-ngx.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "paperless-ngx.labels" -}}
helm.sh/chart: {{ include "paperless-ngx.chart" . }}
{{ include "paperless-ngx.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: apps-root
{{- end }}

{{/*
Selector labels
*/}}
{{- define "paperless-ngx.selectorLabels" -}}
app.kubernetes.io/name: {{ include "paperless-ngx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Tika helpers
*/}}
{{- define "tika.fullname" -}}
{{- .Values.tika.fullnameOverride | default "tika" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tika.labels" -}}
app.kubernetes.io/name: tika
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: apps-root
helm.sh/chart: {{ include "paperless-ngx.chart" . }}
{{- end -}}

{{- define "tika.selectorLabels" -}}
app.kubernetes.io/name: tika
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Gotenberg helpers
*/}}
{{- define "gotenberg.fullname" -}}
{{- .Values.gotenberg.fullnameOverride | default "gotenberg" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "gotenberg.labels" -}}
app.kubernetes.io/name: gotenberg
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: apps-root
helm.sh/chart: {{ include "paperless-ngx.chart" . }}
{{- end -}}

{{- define "gotenberg.selectorLabels" -}}
app.kubernetes.io/name: gotenberg
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Paperless-AI helpers
*/}}
{{- define "paperless-ai.fullname" -}}
{{- .Values.paperlessAi.fullnameOverride | default "paperless-ai" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "paperless-ai.labels" -}}
app.kubernetes.io/name: paperless-ai
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: apps-root
helm.sh/chart: {{ include "paperless-ngx.chart" . }}
{{- end -}}

{{- define "paperless-ai.selectorLabels" -}}
app.kubernetes.io/name: paperless-ai
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Shared Paperless runtime environment
*/}}
{{- define "paperless-ngx.runtimeEnv" -}}
- name: PAPERLESS_URL
  value: {{ .Values.paperless.url | quote }}
- name: PAPERLESS_TIME_ZONE
  value: {{ .Values.paperless.timeZone | quote }}
- name: PAPERLESS_OCR_LANGUAGE
  value: {{ .Values.paperless.ocrLanguage | quote }}
- name: PAPERLESS_OCR_MODE
  value: {{ .Values.paperless.ocrMode | quote }}
- name: PAPERLESS_OCR_CLEAN
  value: {{ .Values.paperless.ocrClean | quote }}
- name: PAPERLESS_OCR_DESKEW
  value: {{ .Values.paperless.ocrDeskew | quote }}
- name: PAPERLESS_OCR_ROTATE_PAGES
  value: {{ .Values.paperless.ocrRotatePages | quote }}
- name: PAPERLESS_OCR_OUTPUT_TYPE
  value: {{ .Values.paperless.ocrOutputType | quote }}
- name: PAPERLESS_FILENAME_DATE_ORDER
  value: {{ .Values.paperless.filenameDateOrder | quote }}
{{- if .Values.paperless.tika.enabled }}
- name: PAPERLESS_TIKA_ENABLED
  value: "true"
- name: PAPERLESS_TIKA_GOTENBERG_ENDPOINT
  value: {{ .Values.paperless.tika.gotenbergEndpoint | quote }}
- name: PAPERLESS_TIKA_ENDPOINT
  value: {{ .Values.paperless.tika.tikaEndpoint | quote }}
{{- end }}
- name: PAPERLESS_REDIS
  value: {{ .Values.paperless.redisUrl | quote }}
- name: PAPERLESS_DBHOST
  value: {{ .Values.paperless.database.host | quote }}
- name: PAPERLESS_DBPORT
  value: {{ .Values.paperless.database.port | quote }}
- name: PAPERLESS_DBNAME
  value: {{ .Values.paperless.database.name | quote }}
- name: PAPERLESS_DBUSER
  value: {{ .Values.paperless.database.user | quote }}
- name: PAPERLESS_DBPASS
  valueFrom:
    secretKeyRef:
      name: {{ .Values.paperless.database.secretName }}
      key: {{ .Values.paperless.database.passwordKey }}
- name: PAPERLESS_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.paperless.secretKey.secretName }}
      key: {{ .Values.paperless.secretKey.key }}
{{- if .Values.paperless.s3.enabled }}
- name: PAPERLESS_STORAGE_BACKEND
  value: "s3"
- name: PAPERLESS_S3_ENDPOINT_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.paperless.s3.existingSecret }}
      key: {{ .Values.paperless.s3.endpointKey }}
- name: PAPERLESS_S3_BUCKET_NAME
  value: {{ .Values.paperless.s3.bucket | quote }}
- name: PAPERLESS_S3_REGION_NAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.paperless.s3.existingSecret }}
      key: {{ .Values.paperless.s3.regionKey }}
- name: PAPERLESS_S3_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.paperless.s3.existingSecret }}
      key: {{ .Values.paperless.s3.accessKeyIdKey }}
- name: PAPERLESS_S3_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.paperless.s3.existingSecret }}
      key: {{ .Values.paperless.s3.secretAccessKeyKey }}
{{- else }}
- name: PAPERLESS_MEDIA_ROOT
  value: {{ .Values.paperless.persistence.media.mountPath | quote }}
{{- end }}
- name: PAPERLESS_DATA_DIR
  value: {{ .Values.paperless.persistence.data.mountPath | quote }}
- name: PAPERLESS_CONSUMPTION_DIR
  value: {{ .Values.paperless.persistence.consume.mountPath | quote }}
- name: PAPERLESS_CONSUMER_POLLING
  value: {{ .Values.paperless.consumerPollingSeconds | quote }}
- name: USERMAP_UID
  value: "1000"
- name: USERMAP_GID
  value: "1000"
{{- if .Values.paperless.oidc.enabled }}
- name: PAPERLESS_APPS
  value: {{ .Values.paperless.oidc.appsValue | quote }}
- name: PAPERLESS_SOCIALACCOUNT_PROVIDERS
  valueFrom:
    secretKeyRef:
      name: {{ .Values.paperless.oidc.secretName }}
      key: {{ .Values.paperless.oidc.providersKey }}
- name: PAPERLESS_SOCIAL_AUTO_SIGNUP
  value: {{ .Values.paperless.oidc.autoSignup | quote }}
- name: PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS
  value: {{ .Values.paperless.oidc.allowSignups | quote }}
- name: PAPERLESS_SOCIAL_ACCOUNT_DEFAULT_GROUPS
  value: {{ .Values.paperless.oidc.defaultGroups | join "," | quote }}
- name: PAPERLESS_DISABLE_REGULAR_LOGIN
  value: {{ .Values.paperless.oidc.disableRegularLogin | quote }}
- name: PAPERLESS_REDIRECT_LOGIN_TO_SSO
  value: {{ .Values.paperless.oidc.redirectLoginToSso | quote }}
{{- end }}
{{- end }}
