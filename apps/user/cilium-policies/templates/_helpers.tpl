{{/*
DNS egress — allows DNS resolution via CoreDNS with Cilium DNS proxy.
Usage: {{ include "cilium-policies.dns-egress" . | nindent N }}
*/}}
{{- define "cilium-policies.dns-egress" -}}
- toEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: kube-system
        k8s-app: kube-dns
  toPorts:
    - ports:
        - port: "53"
          protocol: ANY
      rules:
        dns:
          - matchPattern: "*"
{{- end -}}

{{/*
Kube-API egress — replaces ipBlock 0.0.0.0/0:6443 with entity.
Usage: {{ include "cilium-policies.kube-api-egress" . | nindent N }}
*/}}
{{- define "cilium-policies.kube-api-egress" -}}
- toEntities:
    - kube-apiserver
  toPorts:
    - ports:
        - port: "6443"
          protocol: TCP
{{- end -}}

{{/*
HTTPS egress to internet — replaces ipBlock 0.0.0.0/0:443.
Usage: {{ include "cilium-policies.world-https-egress" . | nindent N }}
*/}}
{{- define "cilium-policies.world-https-egress" -}}
- toEntities:
    - world
  toPorts:
    - ports:
        - port: "443"
          protocol: TCP
# In-cluster HTTPS via Traefik LB — Cilium DNATs LB VIP to pod before
# policy evaluation, so toEntities:world does not match.
- toEndpoints:
    - matchLabels:
        app.kubernetes.io/name: traefik
        k8s:io.kubernetes.pod.namespace: traefik
  toPorts:
    - ports:
        - port: "443"
          protocol: TCP
{{- end -}}

{{/*
Kubelet probe ingress — replaces ipBlock 10.0.20.0/24.
Usage: {{ include "cilium-policies.probe-ingress" . | nindent N }}
*/}}
{{- define "cilium-policies.probe-ingress" -}}
- fromEntities:
    - host
    - remote-node
{{- end -}}
