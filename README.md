# Sentiment Analysis API with Nginx Gateway

A production-ready MLOps setup that serves a sentiment analysis model through a secure, scalable API gateway. This was built as part of an MLOps exam focusing on real-world deployment patterns.

## What This Does

The project deploys a sentiment recognition model that analyzes text and determines the emotional tone (anger, happiness, sadness, etc.). Instead of a simple API, this implements proper production patterns you'd actually want in a real system:

- **Nginx as API Gateway** - Single entry point handling all routing, security, and traffic management
- **Load-balanced API** - 3 replicas of the main API for high availability
- **HTTPS with auto-redirect** - All traffic is encrypted (using self-signed certs)
- **Basic authentication** - Protects the prediction endpoint
- **Rate limiting** - Prevents API abuse (10 req/sec per IP)
- **A/B testing** - Routes to different API versions based on headers
- **Full monitoring stack** - Prometheus + Grafana for observability

## Quick Start

```bash
# Start everything (builds containers, generates certs, starts services)
make start-project # or make up

# Run the test suite
make test

# Stop everything when done
make stop-project # or make down
```

After starting, the services are available at:
- **API**: https://localhost (credentials: `admin/admin`)
- **Grafana**: http://localhost:3000 (credentials: `admin/admin`)
- **Prometheus**: http://localhost:9090

## Architecture

```
                                    ┌─────────────────┐
                                    │     Client      │
                                    └────────┬────────┘
                                             │ HTTPS
                                             ▼
                                    ┌─────────────────┐
                                    │  Nginx Gateway  │
                                    │  - SSL/TLS      │
                                    │  - Auth         │
                                    │  - Rate Limit   │
                                    │  - A/B Routing  │
                                    └────────┬───┬────┘
                                             │   |
                        ┌────────────────────┼────────────────────┐
                        ▼                    ▼   |                ▼
              ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
              │   API v1 - Rep1  │  │   API v1 - Rep2  │  │   API v1 - Rep3  │
              │   (Standard)     │  │   (Standard)     │  │   (Standard)     │
              └──────────────────┘  └──────────────────┘  └──────────────────┘
                                                 │
                                                 │
                                                 ▼ (if X-Experiment-Group: debug)
                                        ┌──────────────────┐
                                        │     API v2       │
                                        │  (Debug mode)    │
                                        └──────────────────┘
```

## How It Works

### The APIs

There are two versions of the sentiment analysis API:

**API v1** (Standard):
- Returns just the predicted emotion
- Deployed with 3 replicas for load balancing
- Production version

**API v2** (Debug):
- Returns prediction + probability distribution for all emotions
- Single instance
- Only accessible with `X-Experiment-Group: debug` header

Both versions use the same pre-trained model (`model.joblib`) that classifies text into 13 emotion categories.

### Making Predictions

Standard prediction (goes to v1):
```bash
curl -X POST "https://localhost/predict" \
  -H "Content-Type: application/json" \
  -d '{"sentence": "I love this so much!"}' \
  --user admin:admin \
  --insecure
```

Debug prediction (goes to v2):
```bash
curl -X POST "https://localhost/predict" \
  -H "Content-Type: application/json" \
  -H "X-Experiment-Group: debug" \
  -d '{"sentence": "I love this so much!"}' \
  --user admin:admin \
  --insecure
```

The debug version returns additional `prediction_proba_dict` with confidence scores for all emotion classes.

### Security Features

**HTTPS Enforcement**: All HTTP requests are automatically redirected to HTTPS. Self-signed certificates are generated on first run.

**Basic Authentication**: The `/predict` endpoint requires username/password. Default credentials are in `.htpasswd` (admin/admin).

**Rate Limiting**: Each IP is limited to 10 requests per second on the `/predict` endpoint (with a burst of 2 for minimal traffic spikes). Excess requests are immediately rejected with HTTP 503. This prevents API abuse and maintains service stability.

### A/B Testing

The routing logic is simple but powerful:
- By default, all traffic goes to api-v1 (load balanced across 3 replicas)
- If you include `X-Experiment-Group: debug` header, you hit api-v2 instead
- This lets you test new features or debug issues without affecting production traffic

This is implemented in `nginx.conf` using the `map` directive:

```nginx
map $http_x_experiment_group $backend {
    default "api-v1";
    "debug" "api-v2";
}
```

## Monitoring

The project includes a full monitoring stack with automatic configuration:

- **Nginx Exporter**: Scrapes metrics from nginx's stub_status endpoint
- **Prometheus**: Collects and stores metrics (data persists across restarts)
- **Grafana**: Visualizes everything with pre-configured dashboards

### Automatic Setup

Grafana is pre-configured with:
- ✅ **Prometheus datasource** automatically connected
- ✅ **"Nginx MLOps Monitoring" dashboard** ready to use
- ✅ **Persistent storage** - all your dashboards and settings are saved

Once running, go to Grafana at http://localhost:3000 (login: `admin/admin`). The pre-loaded dashboard shows:
- Request rates (requests/second)
- Active connections
- Connection trends
- Total HTTP requests

You can customize existing dashboards or create new ones - all changes persist across container restarts thanks to Docker volume storage.

## Testing

The test suite (`tests/run_tests.sh`) validates all the key features:

```bash
make test
```

It checks:
1. ✓ HTTP redirects to HTTPS
2. ✓ Authentication is required for `/predict`
3. ✓ Standard requests work (v1)
4. ✓ Debug header routes to v2 (returns probability dict)
5. ✓ Rate limiting kicks in after threshold
6. ✓ All services are healthy
7. ✓ Monitoring stack is operational

## Project Structure

```
.
├── deployments/
│   ├── nginx/
│   │   ├── certs/               # SSL certificates (auto-generated)
│   │   ├── .htpasswd            # Basic auth credentials
│   │   ├── Dockerfile           # Nginx container setup
│   │   └── nginx.conf           # Main nginx configuration
│   ├── grafana/
│   │   ├── dashboards/          # Pre-configured Grafana dashboards
│   │   ├── provisioning/        # Auto-configuration for Grafana
│   │   │   ├── datasources/     # Prometheus datasource config
│   │   │   └── dashboards/      # Dashboard provider config
│   │   └── README.md            # Grafana setup documentation
│   └── prometheus/
│       └── prometheus.yml       # Prometheus scrape config
├── src/
│   └── api/
│       ├── requirements.txt     # Python dependencies
│       ├── v1/
│       │   ├── Dockerfile       # API v1 container
│       │   └── main.py          # FastAPI app (standard)
│       └── v2/
│           ├── Dockerfile       # API v2 container
│           └── main.py          # FastAPI app (debug)
├── model/
│   └── model.joblib             # Pre-trained sentiment model
├── tests/
│   └── run_tests.sh             # Automated test suite
├── docker-compose.yml           # Orchestrates all services
└── Makefile                     # Common commands
```

## Development Notes

### Certificates

Self-signed certificates are automatically generated when you run `make start-project`. They're valid for 365 days. For production, you'd use proper certificates from Let's Encrypt or similar.

### Scaling

The api-v1 service is configured with 3 replicas in `docker-compose.yml`. Docker Compose handles the load balancing automatically when you access the service name. To change the number of replicas, just update the `replicas` value:

```yaml
api-v1:
  deploy:
    replicas: 5  # or whatever you need
```

### Adding New API Versions

To add a new API version:
1. Create a new directory in `src/api/` (e.g., `v3/`)
2. Add the Dockerfile and Python code
3. Add the service to `docker-compose.yml`
4. Update `nginx.conf` to add routing logic
5. Update the tests

### Troubleshooting

**Can't connect to API**: Wait ~15 seconds after starting for all services to be ready. Check logs with `make logs`.

**Certificate warnings**: Normal for self-signed certs. Use `--insecure` flag with curl or accept the browser warning.

**Tests failing**: Make sure all services are running (`docker-compose ps`). Sometimes the startup takes longer on slower machines.

**Rate limit errors**: If you're testing heavily, you might hit the rate limit. Wait a second or increase the limit in `nginx.conf`.

## Requirements

- Docker
- Docker Compose
- OpenSSL (for certificate generation)
- curl (for testing)
- bash (for test scripts)


## License

This is an exam project for educational purposes.

