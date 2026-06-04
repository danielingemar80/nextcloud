# nextcloud-multitenancy Helm Chart

A production-ready Helm chart deploying Nextcloud with:

- **PHP-FPM** (nextcloud container) + **Nginx** sidecar (reverse proxy) per tenant pod
- **Redis** (shared StatefulSet) for distributed file locking and session caching
- **CronJobs** per tenant for background task processing (`occ maintenance:cron`)
- **Multi-tenant** isolation: each customer gets its own Deployment, Service, Ingress, PVCs, ConfigMaps, and Secrets
- **HPA** support per tenant for autoscaling
- **RollingUpdate** deployment strategy with zero downtime

---

## Architecture

```
Internet
    │
    ▼
[Ingress / nginx-ingress]
    │  (routes by hostname)
    ├──► Service: nextcloud-acme     ──► Pod(s): nginx + php-fpm  ─┐
    └──► Service: nextcloud-globex   ──► Pod(s): nginx + php-fpm   │
                                                                     │
                                          Redis StatefulSet  ◄───────┘
                                          (shared, one per release)

CronJobs (one per tenant, every 5 min by default)
    └── php cron.php (Nextcloud background jobs)
```

## Prerequisites

| Component | Requirement |
|-----------|-------------|
| Kubernetes | ≥ 1.25 |
| Helm | ≥ 3.10 |
| StorageClass | ReadWriteMany (NFS / CephFS / AWS EFS) |
| External DB | MySQL 8+ or PostgreSQL 14+ per tenant |
| Ingress controller | nginx-ingress recommended |
| cert-manager | Optional (for TLS) |

## Quick Start

```bash
# 1. Clone / copy the chart
cp -r nextcloud-helm/ my-nextcloud/

# 2. Edit values
vim my-nextcloud/values.yaml

# 3. Install
helm install nextcloud ./my-nextcloud \
  --namespace nextcloud \
  --create-namespace \
  --values my-nextcloud/values.yaml

# 4. Watch rollout
kubectl rollout status deploy/nextcloud-acme -n nextcloud
```

## Adding a New Tenant

Add an entry to the `tenants:` list in `values.yaml`:

```yaml
tenants:
  - name: newcorp
    enabled: true
    nextcloud:
      host: cloud.newcorp.example.com
      adminUser: admin
      adminPassword: "secure-password"
    database:
      type: mysql
      host: newcorp-mysql.databases.svc.cluster.local
      port: 3306
      name: nextcloud
      user: nextcloud
      password: "db-password"
    replicaCount: 2
    persistence:
      data:
        enabled: true
        size: 200Gi
      html:
        enabled: true
        size: 10Gi
    ingress:
      enabled: true
      className: nginx
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-prod
      tls:
        enabled: true
        secretName: newcorp-tls
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
      limits:
        cpu: 2000m
        memory: 2Gi
```

Then upgrade:
```bash
helm upgrade nextcloud ./my-nextcloud -n nextcloud
```

## Disabling a Tenant

Set `enabled: false` on the tenant entry. **PVCs are preserved** by default
(`helm.sh/resource-policy: keep`) — delete manually if you want to reclaim storage.

## Using External Secrets

Instead of storing passwords in `values.yaml`, create a Kubernetes Secret
manually and reference it:

```yaml
tenants:
  - name: acme
    nextcloud:
      adminPassword: ""          # ignored when existingSecret is set
    database:
      password: ""
      existingSecret: acme-nextcloud-secret   # keys: nextcloud-password, db-password
```

## Key values reference

| Key | Default | Description |
|-----|---------|-------------|
| `global.storageClass` | `""` | Default StorageClass for all PVCs |
| `redis.enabled` | `true` | Deploy shared Redis |
| `redis.password` | `changeme` | Redis AUTH password |
| `cronjob.enabled` | `true` | Enable per-tenant cron jobs |
| `cronjob.schedule` | `*/5 * * * *` | Cron schedule |
| `tenants[].replicaCount` | `1` | Pod replicas per tenant |
| `tenants[].autoscaling.enabled` | `false` | Enable HPA |
| `nginx.clientMaxBodySize` | `10G` | Max upload size |

## OCC Commands

```bash
# Run an OCC command for a specific tenant
kubectl exec -n nextcloud \
  $(kubectl get pod -n nextcloud -l tenant=acme -o name | head -1) \
  -c nextcloud -- php occ <command>

# Examples
php occ maintenance:mode --on
php occ files:scan --all
php occ upgrade
php occ user:list
```

## Upgrade Nextcloud

1. Update `image.tag` in `values.yaml`
2. `helm upgrade nextcloud ./my-nextcloud -n nextcloud`
3. Run `php occ upgrade` in each tenant pod after the rollout completes

## Security Considerations

- All passwords should be rotated before production deployment
- Use an External Secrets Operator (ESO) or Vault Agent for secret injection
- Redis password is shared across tenants — use separate Redis per tenant for stricter isolation
- PVCs use `ReadWriteMany` — ensure your CSI driver encrypts data at rest
