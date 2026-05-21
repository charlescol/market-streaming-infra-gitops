# Market Streaming Infrastructure GitOps

GKE and GitOps configuration for the real-time market-data pipeline.

This repository is part of the [Real-Time Market Data System](https://github.com/charlescol/real-time-market-data-system). It defines the Kubernetes deployment layer of the system, including Kafka, Flink, exchange ingestion services, snapshot middleware, Schema Registry, Druid, and monitoring.

The GKE cluster and cloud resources are provisioned separately with Terraform in [market-streaming-infra-terraform](https://github.com/charlescol/market-streaming-infra-terraform). This repository defines the cluster state reconciled by Flux.

## Scope

This repository contains Kubernetes manifests, Kustomize overlays, Flux resources, Helm releases, monitoring definitions, storage configuration, and application deployment descriptors. Application source code lives in separate repositories.

## Environments

The root folders define deployable environments.

- `binance` deploys a Binance-only pipeline.
- `kucoin` deploys a KuCoin-only pipeline.
- `binance-kucoin` deploys the two-exchange setup used for the main live experiment and downstream analysis.

Each environment follows the same general layout.

```
<environment>/
├── apps/          # Application deployments and service-level configuration
├── common/        # Shared Kubernetes resources, storage, CRDs, roles, scripts
├── flux-system/   # Flux GitOps synchronization resources
├── helm/          # Helm releases for external infrastructure components
└── kustomization.yaml
```

## Main components

The GitOps configuration covers the main services required to run the pipeline.

- **Kafka**  
  Transport layer for update streams, snapshot streams, and derived feature streams.

- **Flink**  
  Stateful stream-processing layer for order-book reconstruction and feature extraction.

- **Scrapers**  
  Exchange feed handlers for live Binance and KuCoin update ingestion.

- **Snapshot middleware**  
  Services used by the order-book engine to retrieve exchange snapshots during initialization and recovery.

- **Schema Registry**  
  Schema service used by the pipeline message formats.

- **Druid**  
  Analytical storage used for persisted feature streams and offline analysis.

- **Prometheus and Grafana**  
  Monitoring stack for rates, resource usage, queues, saturation events, and service health.

- **Pyroscope**  
  Continuous profiling support for deployed services.

## Usage

List available commands.

```
make help
```

Check that the local environment is correctly configured for a target deployment.

```
make check_env ENV=binance
```

Bootstrap an environment and apply its configuration.

```
make bootstrap ENV=binance
```

Other valid environments include:

```
ENV=kucoin
ENV=binance-kucoin
```

`kubectl` must be configured with the target cluster context before applying these commands.
