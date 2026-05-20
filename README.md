# Deploy and Host SigNoz on Railway

**[SigNoz](https://signoz.io)** is an open-source observability platform that enables you to collect, store, and analyze distributed application **traces, metrics, and logs** using the OpenTelemetry standard.

## About Hosting SigNoz

When you deploy SigNoz on Railway, the following core services are provisioned:
- SigNoz
- SigNoz Otel Collector
- ClickHouse
- Zookeeper

The Railway template automatically sets up these services with the necessary environment variables, health checks, and persistent storage. This allows you to quickly go from deployment to creating dashboards. Simply point your application's OpenTelemetry SDK or agent to the provided ingest URL, and SigNoz will immediately begin visualizing service dependencies, latency, and errors.

## Common Use Cases

- **Application Performance Monitoring**: Monitor metrics, logs, and traces across your entire Railway application stack.
- **Debugging and Troubleshooting**: Correlate logs, metrics, and traces to quickly identify and resolve issues.
- **Infrastructure Observability**: Monitor system health, resource usage, and service dependencies in real time.
- **Alerting and Incident Response**: Set up alerts based on metrics and log patterns for proactive incident management.

## Dependencies for SigNoz Hosting

- **Persistent Storage**: Use a Railway volume (or external block storage) for ClickHouse and SigNoz data.
- **Ingest Traffic**: Applications should export OpenTelemetry traces, metrics, or logs over HTTP or gRPC.

### Deployment Dependencies

- [SigNoz Documentation](https://signoz.io/docs/)
- [OpenTelemetry Specification](https://opentelemetry.io/docs/)
- [ClickHouse Server](https://clickhouse.com/docs/en/)

### Implementation Details

To run the SigNoz stack on Railway, ensure the following:

#### Service Dockerfiles
- `signoz`: `signoz/Dockerfile.signoz`
- `signoz-otel-collector`: `signoz/Dockerfile.otel`
- `signoz-telemetrystore-migrator`: `signoz/Dockerfile.migrator`
- `clickhouse`: `clickhouse/Dockerfile.clickhouse`

#### OpenTelemetry Ingestion
- You may need to configure **Domains / Proxy** settings in Railway for the `signoz-otel-collector` service, depending on your use case.  
- Port **4317** is open for ingestion by default.

#### PostgreSQL and Redis Metrics

The `signoz-otel-collector` image already includes the receivers required by the SigNoz PostgreSQL and Redis integrations, so database metrics can be collected by the existing collector service instead of deploying a second collector service.

The opt-in combined config scrapes the production Postgres HA endpoint and the five production Redis services:

- Postgres HA: `postgres-ha.railway.internal:5432`
- Cyberpunk Redis: `redis-d7a4.railway.internal:6379`
- Gateway Redis: `redis-20e3.railway.internal:6379`
- Gundam Redis: `redis-6c5d.railway.internal:6379`
- Lorcana Redis: `redis.railway.internal:6379`
- Web Redis: `redis-daa5.railway.internal:6379`

To enable this path, set these Railway variables on the `signoz-otel-collector` service:

- `POSTGRESQL_PASSWORD`: monitoring user password. This is required and must match the production Postgres `monitoring` user.
- `POSTGRESQL_ENDPOINT`: defaults to `postgres-ha.railway.internal:5432`.
- `POSTGRESQL_USERNAME`: defaults to `monitoring`.
- `POSTGRESQL_SERVICE_NAME`: defaults to `postgres-ha`.
- `POSTGRESQL_COLLECTION_INTERVAL`: defaults to `60s`.
- `POSTGRESQL_TLS_INSECURE`: defaults to `true`.
- `DEPLOYMENT_ENVIRONMENT`: defaults to `production`.
- `REDIS_CYBERPUNK_PASSWORD`: reference `cyberpunk/redis.REDIS_PASSWORD`.
- `REDIS_GATEWAY_PASSWORD`: reference `gateway/redis.REDIS_PASSWORD`.
- `REDIS_GUNDAM_PASSWORD`: reference `gundam/redis.REDIS_PASSWORD`.
- `REDIS_LORCANA_PASSWORD`: reference `lorcana/redis.REDIS_PASSWORD`.
- `REDIS_WEB_PASSWORD`: reference `web/redis.REDIS_PASSWORD`.
- `REDIS_COLLECTION_INTERVAL`: defaults to `60s`.

Then update the `signoz-otel-collector` start command to use the combined config:

```sh
/bin/sh -c "/signoz-otel-collector migrate sync check && exec /signoz-otel-collector --config=/etc/otel-collector-config-postgres.yaml --copy-path=/var/tmp/collector-config.yaml"
```

The combined config lives at `signoz/otel-collector-config-postgres.yaml` and keeps the normal SigNoz OTLP, Prometheus, traces, metrics, and logs pipelines while adding Postgres and Redis metrics pipelines. Do not pass `--manager-config` with this opt-in database metrics config: OpAMP can reload the default collector config and drop the database receivers. PostgreSQL and Redis log collection require the collector to read the database server log files, which is usually not available from separate Railway managed database services.

Create the Postgres monitoring user once on the production cluster:

```sql
CREATE USER monitoring WITH PASSWORD '<generated-password>';
GRANT pg_monitor TO monitoring;
GRANT SELECT ON pg_stat_database TO monitoring;
```

#### SigNoz UI
- A public domain is configured automatically in Railway to access the SigNoz dashboard.
- SigNoz listens on port **8080** and Railway probes `/api/v1/health`. Keep the `signoz` service variable `PORT=8080` when possible. The Dockerfile also includes a small forwarder so deployments still answer Railway healthchecks if Railway injects a different `PORT`.
- Set `SIGNOZ_TOKENIZER_JWT_SECRET` on the `signoz` service with a generated secret, for example `${{ secret(32) }}` in the Railway template editor.

#### Schema-Migration Order
ClickHouse migrations run in the dedicated **`signoz-telemetrystore-migrator`** job. This template builds that job from `signoz/Dockerfile.migrator`, which uses the current SigNoz otel-collector migration command:

```sh
/signoz-otel-collector migrate bootstrap &&
/signoz-otel-collector migrate sync up &&
/signoz-otel-collector migrate async up
```

Do not deploy the legacy `signoz/signoz-schema-migrator` image with ClickHouse `25.5.6`; it can fail during startup with `NO_SUCH_COLUMN_IN_TABLE` for `timestamp`.

As Railway does not yet offer Docker-style `depends_on`, dependent services can occasionally start before migrations finish and fail on their first boot. If that happens, **redeploy these services after the migrator job completes**, in the exact order shown:

1. **signoz-telemetrystore-migrator**
2. **signoz** (main application)
3. **signoz-otel-collector**

After redeploying in this sequence, all components will connect to ClickHouse with the correct schema and operate normally.

## Why Deploy

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying SigNoz on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
