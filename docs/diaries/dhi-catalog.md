# DHI Catalog & Migration Plan

Generated: 2026-02-09

## DHI Helm Charts Available (34 total)

| DHI Chart Slug | Display Name |
|---|---|
| alertmanager-chart | Prometheus AlertManager Helm chart |
| alloy-chart | Grafana Alloy Helm Chart |
| azure-service-operator-chart | Azure Service Operator Helm chart |
| cert-manager-chart | Cert-Manager Helm chart |
| clickhouse-operator-chart | ClickHouse Operator Helm chart |
| cloudnative-pg-chart | CloudNativePG Helm chart |
| dex-chart | Dex Helm chart |
| external-dns-chart | External DNS Helm chart |
| external-secrets-chart | External Secrets Operator Helm chart |
| fluent-bit-chart | Fluent Bit Helm chart |
| grafana-agent-chart | Grafana Agent Helm chart |
| haproxy-chart | HAProxy Helm chart |
| kube-state-metrics-chart | Kube State Metrics Helm chart |
| kubernetes-cluster-autoscaler-chart | Kubernetes Cluster Autoscaler Helm Chart |
| kyverno-policy-reporter-chart | Kyverno Policy Reporter Helm chart |
| metrics-server-chart | Metrics Server Helm chart |
| neo4j-chart | Neo4j |
| node-exporter-chart | Prometheus Node Exporter Helm chart |
| opensearch-chart | OpenSearch Helm chart |
| opensearch-dashboards-chart | OpenSearch Dashboards Helm chart |
| opentelemetry-collector-chart | OpenTelemetry Collector Helm chart |
| prometheus-nats-exporter-chart | Prometheus NATS Exporter Helm chart |
| promtail-chart | Promtail Helm chart |
| pyroscope-chart | Pyroscope |
| redis-chart | Redis Helm Chart |
| sealed-secrets-chart | Sealed Secrets Controller Helm chart |
| strimzi-kafka-operator-chart | Strimzi Kafka Operator Helm chart |
| traefik-chart | Traefik Helm chart |
| valkey-chart | Valkey Helm chart |
| vault-chart | Vault Helm chart |
| vector-chart | Vector Helm chart |
| victoriametrics-alert-chart | VictoriaMetrics Alerts Helm chart |
| victoriametrics-cluster-chart | VictoriaMetrics Cluster Helm chart |
| ztunnel-chart | Istio Ztunnel Helm chart |

## DHI Hardened Images Available (290 total)

| DHI Image Slug | Display Name |
|---|---|
| activemq-artemis | ActiveMQ Artemis |
| airflow | Airflow |
| alertmanager | Prometheus Alertmanager |
| alloy | Grafana Alloy |
| alpine-base | Alpine Base |
| amazoncorretto | Amazon Corretto |
| apigee-microgateway | Apigee Edge Microgateway |
| apisix | APISIX |
| argo-events | Argo Events |
| argo-workflow-controller | Argo Workflow Controller |
| argocd | Argo CD |
| argocd-image-updater | Argo CD Image Updater |
| argocli | Argo CLI |
| argoexec | Argo executor |
| aspnetcore | ASP.NET Core |
| awscli | AWS CLI |
| azul | Azul Platform Prime |
| azure-functions-node | Azure Functions (Node.js) |
| azure-functions-python | Azure Functions (Python) |
| azure-metrics-exporter | Azure Metrics Exporter |
| azure-service-operator | Azure Service Operator |
| bash | Bash |
| bats | BATS |
| build | DHI Build |
| buildkit | Moby Buildkit |
| bun | Bun |
| busybox | BusyBox |
| caddy | Caddy |
| calico-cni | Calico CNI |
| calico-kube-controllers | Calico Kube Controllers |
| cdi-apiserver | CDI API Server |
| cert-manager-acmesolver | cert-manager-acmesolver |
| cert-manager-cainjector | cert-manager-cainjector |
| cert-manager-controller | cert-manager-controller |
| cert-manager-istio-csr | cert-manager-istio-csr |
| cert-manager-startupapicheck | cert-manager-startupapicheck |
| cert-manager-webhook | cert-manager-webhook |
| cilium-certgen | Cilium Certgen |
| cilium-clustermesh-apiserver | Cilium Clustermesh API Server |
| cilium-operator | Cilium Operator |
| cilium-operator-aws | Cilium Operator AWS |
| cilium-operator-azure | Cilium Operator Azure |
| cilium-operator-generic | Cilium Operator Generic |
| cilium-startup-script | Cilium startup script |
| clamav | clamav |
| clickhouse-metrics-exporter | ClickHouse Metrics Exporter |
| clickhouse-operator | ClickHouse Operator |
| clickhouse-server | ClickHouse |
| cloudnative-pg | CloudNativePG |
| cloudnative-pg-plugin-barman-cloud | CloudNativePG Barman Plugin |
| cloudnative-pg-plugin-barman-cloud-sidecar | CloudNativePG Barman Cloud Plugin Sidecar |
| composer | Composer |
| configmap-reload | configmap-reload |
| context7-mcp | Upstash Context7 MCP Server |
| contour | Contour |
| coredns | CoreDNS |
| cosign | Cosign |
| couchdb | CouchDB |
| crane | Crane |
| csi-attacher | CSI Attacher |
| csi-external-health-monitor-controller | CSI External Health Monitor Controller |
| csi-hostpath-plugin | CSI Hostpath Plugin |
| csi-node-driver-registrar | CSI Node Driver Registrar |
| csi-provisioner | CSI Provisioner |
| csi-resizer | CSI Resizer |
| csi-snapshotter | CSI Snapshotter |
| curl | curl |
| dart | Dart |
| debian-base | Debian Base |
| delve | Delve |
| deno | Deno |
| dex | Dex |
| docker | Docker |
| dotnet | .NET |
| drbd-reactor | drbd-reactor |
| drbd-utils | drbd-utils |
| eclipse-mosquitto | Eclipse Mosquitto |
| eclipse-temurin | Eclipse Temurin |
| elasticsearch | Elasticsearch |
| emissary | Emissary-Ingress |
| envoy | Envoy |
| envoy-ratelimit | Envoy Rate Limit Service |
| erlang-otp | Erlang/OTP |
| etcd | etcd |
| external-dns | ExternalDNS |
| external-secrets | External Secrets Operator |
| fetch-mcp | Fetch MCP Server |
| filebeat | Filebeat |
| filesystem-mcp | Filesystem MCP Server |
| firecrawl-mcp | Firecrawl MCP Server |
| fluent-bit | Fluent Bit |
| fluentd | Fluentd |
| flyway | Flyway |
| frr | FRRouting |
| git-mcp | Git MCP Server |
| github-mcp | GitHub MCP Server |
| gitleaks | Gitleaks |
| go-jsonnet | Jsonnet |
| golang | Go (golang) |
| goldilocks | Goldilocks |
| gradle | Gradle |
| grafana | Grafana |
| grafana-agent | Grafana Agent |
| grafana-mcp | Grafana MCP Server |
| grist | Grist |
| grype | Grype |
| haproxy | HAProxy |
| harbor-jobservice | Harbor Job Service |
| harbor-registryctl | Harbor Registry Control |
| helm | Helm |
| hub-mcp | Docker Hub MCP Server |
| hubble-proto | Cilium Hubble Proto |
| hubble-relay | Cilium Hubble Relay |
| hubble-ui | Cilium Hubble UI |
| hubble-ui-backend | Hubble UI Backend |
| hyperledger-fabric-orderer | Hyperledger Fabric Orderer |
| hyperledger-fabric-tools | Hyperledger Fabric Tools |
| influxdb | InfluxDB |
| istio-install-cni | Istio Install CNI |
| istio-pilot | Istio Pilot |
| istio-proxyv2 | Istio Proxy v2 |
| istioctl | Istioctl |
| jenkins | Jenkins |
| jenkins-agent | Jenkins Agent |
| jenkins-inbound-agent | Jenkins Inbound Agent |
| jmx-exporter | JMX Exporter |
| jruby | JRuby |
| k6 | k6 |
| k8s-sidecar | k8s-sidecar |
| kafka | Kafka |
| kafka-exporter | Kafka Exporter |
| karpenter | karpenter |
| keda | KEDA |
| keda-admission-webhooks | KEDA Admission Webhooks |
| keda-metrics-apiserver | KEDA Metrics API Server |
| keycloak | Keycloak |
| kibana | Kibana |
| kserve-agent | KServe Agent |
| kserve-controller | KServe Controller |
| kserve-localmodel-controller | KServe LocalModel Controller |
| kserve-localmodelnode-agent | KServe LocalModelNode Agent |
| kserve-router | KServe Router |
| kserve-storage-initializer | KServe Storage Initializer |
| ktls-utils | ktls-utils |
| kube-rbac-proxy | kube-rbac-proxy |
| kube-state-metrics | kube-state-metrics |
| kube-vip | kube-vip |
| kube-webhook-certgen | Kube Webhook Certgen |
| kubectl | kubectl |
| kubeflow-pipelines-apiserver | Kubeflow Pipelines - API Server |
| kubeflow-pipelines-frontend | Kubeflow Pipelines - Frontend |
| kubeflow-pipelines-metadata-writer | Kubeflow Pipelines - Metadata Writer |
| kubernetes-autoscaler-addon-resizer | Kubernetes Autoscaler Addon Resizer |
| kubernetes-cluster-autoscaler | Kubernetes Cluster Autoscaler |
| kubescape-cli | Kubescape CLI |
| kustomize | Kustomize |
| kyverno | Kyverno |
| kyverno-background-controller | Kyverno Background Controller |
| kyverno-cleanup-controller | Kyverno Cleanup Controller |
| kyverno-cli | Kyverno CLI |
| kyverno-init | Kyverno Init |
| kyverno-policy-reporter | Kyverno Policy Reporter |
| kyverno-policy-reporter-ui | Kyverno Policy Reporter UI |
| kyverno-reports-controller | Kyverno Reports Controller |
| linstor-gui | LINSTOR GUI |
| liquibase | Liquibase |
| litellm | LiteLLM |
| livenessprobe | CSI Livenessprobe |
| localstack | LocalStack |
| logstash | Logstash |
| loki | Grafana Loki |
| maven | Maven |
| mediawiki | MediaWiki |
| memcached | Memcached |
| memory-mcp | Memory MCP Server |
| metallb-controller | MetalLB Controller |
| metallb-speaker | MetalLB Speaker |
| metrics-server | Metrics Server |
| mlflow | MLflow |
| mongodb | MongoDB |
| mongodb-exporter | MongoDB Exporter |
| mongodb-kubernetes | MongoDB Controllers for Kubernetes |
| mongodb-mcp | MongoDB MCP Server |
| mysql | MySQL |
| mysqld-exporter | MySQL Server Exporter |
| nats | NATS |
| nats-box | NATS Box |
| nats-server-config-reloader | NATS Server Config Reloader |
| natscli | NATS CLI |
| neo4j | Neo4j |
| netdata | Netdata |
| nginx | Nginx |
| nginx-exporter | Nginx Exporter |
| nifi | Apache NiFi |
| node | Node.js |
| node-exporter | Prometheus Node Exporter |
| notation | notation |
| oauth2-proxy | OAuth2 Proxy |
| open-policy-agent | Open Policy Agent |
| openbao | OpenBao |
| openebs-lvm-driver | OpenEBS LVM LocalPV Driver |
| openfga | OpenFGA |
| openresty | OpenResty |
| openscap | OpenSCAP |
| opensearch | OpenSearch |
| opensearch-dashboards | OpenSearch Dashboards |
| opentelemetry-autoinstrumentation-go | OpenTelemetry Go Autoinstrumentation |
| opentelemetry-collector | OpenTelemetry Collector |
| opentelemetry-operator | OpenTelemetry Operator |
| opentelemetry-target-allocator | OpenTelemetry Target Allocator |
| oras | ORAS |
| pgbouncer | PgBouncer |
| php | PHP |
| pinniped-cli | Pinniped CLI |
| piraeus-csi | Piraeus CSI |
| piraeus-ha-controller | Piraeus HA Controller |
| piraeus-operator | Piraeus Operator |
| polaris | Polaris |
| postgres | PostgreSQL |
| postgres-exporter | PostgreSQL Exporter |
| prometheus | Prometheus |
| prometheus-config-reloader | Prometheus Config Reloader |
| prometheus-nats-exporter | Prometheus NATS Exporter |
| prometheus-operator | Prometheus Operator |
| prometheus-statsd-exporter | StatsD Exporter |
| promtail | Promtail |
| pushgateway | Prometheus Pushgateway |
| pyroscope | Pyroscope |
| python | Python |
| pytorch | PyTorch |
| rabbitmq | RabbitMQ |
| redis | Redis |
| redis-exporter | Redis Exporter |
| regctl | regctl |
| ruby | Ruby |
| rust | Rust |
| sapmachine | SapMachine |
| scout-cli | Docker Scout CLI |
| scout-sbom-indexer | Docker Scout SBOM Indexer |
| sealed-secrets-controller | Sealed Secrets Controller |
| sealed-secrets-kubeseal | Sealed Secrets Kubeseal |
| seaweedfs | SeaweedFS |
| seaweedfs-cosi-driver | SeaweedFS COSI Driver |
| shellcheck | ShellCheck |
| sonarqube | SonarQube |
| spark | Apache Spark |
| spire-agent | SPIFFE SPIRE Agent |
| spire-server | SPIFFE SPIRE Server |
| stakater-reloader | Reloader |
| static | Static |
| strimzi-kafka | Strimzi Kafka |
| strimzi-kafka-bridge | Strimzi Kafka Bridge |
| strimzi-operator | Strimzi Operator for Kafka |
| syft | Syft |
| tailscale | Tailscale |
| tempo | Grafana Tempo |
| temporalio-admin-tools | Temporal Admin Tools |
| temporalio-server | Temporal Server |
| temporalio-ui | Temporal UI |
| tensorflow-serving | Tensorflow Serving |
| thanos | Thanos |
| tigera-operator | Tigera Operator |
| time-mcp | Time MCP Server |
| tomcat | Tomcat |
| traefik | Traefik |
| trino | Trino |
| trivy | Trivy |
| trufflehog | TruffleHog |
| uptime-kuma | Uptime Kuma |
| uv | uv |
| valkey | Valkey |
| vault | Vault |
| vault-csi-provider | Vault CSI Provider |
| vault-k8s | Vault K8s |
| vector | Vector |
| velero | Velero |
| velero-plugin-for-aws | Velero Plugin for AWS |
| velero-plugin-for-gcp | Velero Plugin for GCP |
| velero-plugin-for-microsoft-azure | Velero Plugin for Azure |
| versitygw | VersityGW |
| victoriametrics-vmagent | VictoriaMetrics VMAgent |
| victoriametrics-vmalert | VictoriaMetrics VMAlert |
| victoriametrics-vmauth | VictoriaMetrics VMAuth |
| victoriametrics-vminsert | VictoriaMetrics VMInsert |
| victoriametrics-vmselect | VictoriaMetrics VMSelect |
| victoriametrics-vmstorage | VictoriaMetrics VMStorage |
| wait-for-it | wait-for-it |
| wiremock | WireMock |
| zookeeper | Zookeeper |
| ztunnel | Istio Ztunnel |

---

## Current App Inventory & DHI Match Status

### apps/cluster/

| App | Current Dep | Current Version | Current Repo | DHI Chart? | DHI Image? | Status |
|---|---|---|---|---|---|---|
| alloy | alloy-chart | 1.6.0 | oci://dhi.io | alloy-chart | alloy | DONE |
| argocd | argo-cd | 9.4.1 | argoproj.github.io | NO | argocd | IMAGE-ONLY |
| cert-manager | cert-manager-chart | 1.19.3 | oci://dhi.io | cert-manager-chart | cert-manager-* | DONE |
| cloudflared | cloudflared | 2.2.6 | community-charts | NO | NO | NO DHI |
| cloudnative-pg | cloudnative-pg-chart | 0.27.1 | oci://dhi.io | cloudnative-pg-chart | cloudnative-pg | DONE |
| coredns | coredns | 1.45.2 | coredns.github.io | NO | coredns | IMAGE-ONLY |
| external-dns | external-dns-chart | 1.20.0 | oci://dhi.io | external-dns-chart | external-dns | DONE |
| grafana-mcp | grafana-mcp | 0.5.0 | grafana-community | NO | grafana-mcp | IMAGE-ONLY |
| kube-prometheus-stack | kube-prometheus-stack | 81.5.0 | prometheus-community | NO | grafana, prometheus, alertmanager, node-exporter, kube-state-metrics, prometheus-operator, prometheus-config-reloader, k8s-sidecar | IMAGE-ONLY |
| kured | kured | 5.11.0 | kubereboot | NO | NO | NO DHI |
| local-path | (none) | — | — | NO | NO | N/A |
| loki | loki | 6.52.0 | grafana.github.io | NO | loki | IMAGE-ONLY |
| metallb | metallb | 0.15.3 | metallb.github.io | NO | metallb-controller, metallb-speaker | IMAGE-ONLY |
| minio-operator | operator | 7.1.1 | operator.min.io | NO | NO | NO DHI |
| minio-tenant | tenant | 7.1.1 | operator.min.io | NO | NO | NO DHI |
| namespaces | (none) | — | — | NO | NO | N/A |
| origin-ca-issuer | origin-ca-issuer | 0.6.2 | ghcr.io/cloudflare | NO | NO | NO DHI |
| prometheus-crds | prometheus-operator-crds | 27.0.0 | prometheus-community | NO | NO | N/A (CRDs only) |
| prometheus-pve-exporter | prometheus-pve-exporter | 2.6.1 | christianhuth.de | NO | NO | NO DHI |
| proxmox-csi | proxmox-csi-plugin | 0.5.5 | ghcr.io/sergelogvinov | NO | NO | NO DHI |
| reflector | reflector | 10.0.5 | emberstack | NO | NO | NO DHI |
| sealed-secrets | sealed-secrets | 2.18.0 | bitnami-labs | sealed-secrets-chart | sealed-secrets-controller | INCOMPATIBLE (Bitnami vs upstream) |
| secrets-cluster | (none) | — | — | NO | NO | N/A |
| tailscale-operator | tailscale-operator | 1.94.1 | pkgs.tailscale.com | NO | tailscale | IMAGE-ONLY |
| traefik | traefik | (v39.x via submodule) | — | traefik-chart | traefik | NEEDS VERSION CHECK |
| valkey | valkey-chart | 0.9.3 | oci://dhi.io | valkey-chart | valkey | DONE |

### apps/user/

| App | Current Dep | Current Version | Current Repo | DHI Chart? | DHI Image? | Status |
|---|---|---|---|---|---|---|
| adguardhome-sync | (none) | — | — | NO | NO | NO DHI |
| authentik | authentik | 2025.12.3 | goauthentik.io | NO | NO | NO DHI |
| basic-memory | (none) | — | — | NO | couchdb | IMAGE-ONLY (partial) |
| gitea | gitea | 12.5.0 | dl.gitea.com | NO | NO | NO DHI |
| harbor | harbor | 1.18.2 | goharbor.io | NO | harbor-jobservice, harbor-registryctl | IMAGE-ONLY (partial) |
| harborguard | (none) | — | — | NO | NO | N/A |
| headlamp | headlamp | 0.40.0 | kubernetes-sigs | NO | NO | NO DHI |
| homepage | homepage | 0.3.0 | sm-moshi | NO | NO | NO DHI |
| kubescape-operator | kubescape-operator | 1.30.3 | kubescape.github.io | NO | kubescape-cli | IMAGE-ONLY (partial) |
| netbox | netbox | 7.4.5 | ghcr.io/netbox-community | NO | NO | NO DHI |
| netzbremse | (none) | — | — | NO | NO | N/A |
| pgadmin4 | pgadmin4 | 1.57.0 | rowanruseler | NO | NO | NO DHI |
| proxmenux | (none) | — | — | NO | NO | N/A |
| renovate | (none) | — | — | NO | NO | NO DHI |
| secrets-apps | (none) | — | — | NO | NO | N/A |
| semaphore | semaphore | 16.0.11 | local file:// | NO | NO | NO DHI |
| trivy-operator | trivy-operator | 0.31.0 | aquasecurity | NO | trivy | IMAGE-ONLY (partial) |
| uptime-kuma | uptime-kuma | 2.24.0 | dirsigler | NO | uptime-kuma | IMAGE-ONLY |
| vaultwarden | vaultwarden | 0.34.5 | guerzon | NO | NO | NO DHI |

---

## Migration Priority Queue

### Tier 1: DHI chart available — direct chart swap (like alloy)

| App | DHI Chart | Action |
|---|---|---|
| sealed-secrets | sealed-secrets-chart | BLOCKED — Bitnami lineage mismatch, needs schema migration |
| traefik | traefik-chart | BLOCKED — DHI has v37.x, we run v39.x |

### Tier 2: No DHI chart, but DHI images available — image-only migration

These apps keep their upstream chart but switch container images to `dhi.io/<image>`.

| App | DHI Images Available | Complexity |
|---|---|---|
| kube-prometheus-stack | grafana, prometheus, alertmanager, node-exporter, kube-state-metrics, prometheus-operator, prometheus-config-reloader, k8s-sidecar | HIGH (8+ images) |
| loki | loki | LOW |
| metallb | metallb-controller, metallb-speaker | MEDIUM |
| argocd | argocd | MEDIUM (multiple components use same image) |
| coredns | coredns | LOW |
| tailscale-operator | tailscale | LOW |
| uptime-kuma | uptime-kuma | LOW |
| trivy-operator | trivy | LOW |
| harbor | harbor-jobservice, harbor-registryctl | LOW (partial — not all harbor images in DHI) |
| grafana-mcp | grafana-mcp | LOW |

### Tier 3: No DHI availability — skip

cloudflared, kured, minio-operator, minio-tenant, origin-ca-issuer, prometheus-pve-exporter,
proxmox-csi, reflector, authentik, gitea, headlamp, homepage, netbox, pgadmin4, renovate,
semaphore, vaultwarden, adguardhome-sync

### Not applicable (no upstream chart / local-only)

local-path, namespaces, secrets-cluster, secrets-apps, basic-memory, harborguard, netzbremse, proxmenux
