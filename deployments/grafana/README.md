# Grafana Configuration

## Persistent Storage

Grafana is configured with persistent storage using Docker volumes. All your dashboards, datasources, and settings will be saved automatically and persist across container restarts.

### What's Persisted:

- **User-created dashboards** and modifications
- **Grafana settings** and preferences
- **Users and permissions**
- **Alert configurations**

### Pre-configured Components:

1. **Prometheus Datasource**: Automatically configured and connected to `http://prometheus_server:9090`
2. **Nginx MLOps Dashboard**: Pre-loaded dashboard with key Nginx metrics including:
   - Request rate (requests/second)
   - Active connections
   - Total connections (accepted/handled)
   - Total HTTP requests

### Access Grafana:

- **URL**: http://localhost:3000
- **Username**: admin
- **Password**: admin

### Dashboard Features:

The pre-configured "Nginx MLOps Monitoring" dashboard displays:
- Real-time Nginx request rate
- Active connection gauge
- Connection trends (accepted vs handled)
- Total HTTP request counter

All panels refresh every 5 seconds and show data from the last 15 minutes by default.

### Customization:

You can freely modify dashboards, add new ones, or create additional datasources. All changes will be persisted in the `grafana_data` Docker volume.

To reset Grafana to defaults:
```bash
docker-compose down -v  # This removes all volumes
docker-compose up -d
```

