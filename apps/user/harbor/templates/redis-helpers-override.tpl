{{- /*
Override Harbor redis helper to avoid nil-pointer failures during helm lint
when the external secret does not exist in the lint context.
*/ -}}
{{- define "harbor.redis.pwdfromsecret" -}}
  {{- $secret := (lookup "v1" "Secret" .Release.Namespace (.Values.redis.external.existingSecret)) -}}
  {{- if and $secret (hasKey $secret.data "REDIS_PASSWORD") -}}
    {{- $secret.data.REDIS_PASSWORD | b64dec | trim -}}
  {{- end -}}
{{- end -}}
