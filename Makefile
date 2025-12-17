.PHONY: start-project stop-project test run-project test-api logs certs up down

up: start-project
down: stop-project

# generate SSL certs if they don't exist
certs:
	@if [ ! -f ./deployments/nginx/certs/nginx.crt ]; then \
		echo "Generating SSL certs..."; \
		mkdir -p ./deployments/nginx/certs; \
		openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
			-keyout ./deployments/nginx/certs/nginx.key \
			-out ./deployments/nginx/certs/nginx.crt \
			-subj "/C=DE/ST=Bayern/L=Munich/O=MLOps/CN=localhost" \
			-addext "subjectAltName=DNS:localhost,IP:127.0.0.1"; \
	else \
		echo "Certs already exist, skipping..."; \
	fi

start-project: certs
	@echo "Starting stuff..."
	docker-compose up --build -d
	@echo "Waiting a bit for things to start..."
	@sleep 15
	@echo "CHECK. Should be running now!"
	@echo "Grafana: http://localhost:3000 (admin/admin)"
	@echo "Prometheus: http://localhost:9090"
	@echo "API: https://localhost (admin/admin)"

stop-project:
	@echo "Shutting down..."
	docker-compose down -v
	@echo "Done"

test:
	@bash tests/run_tests.sh

logs:
	docker-compose logs -f

test-api:
	@echo "Quick API test of sentence 'Oh yeah, that was soooo cool!'"
	@curl -s -X POST "https://localhost/predict" \
     -H "Content-Type: application/json" \
     -d '{"sentence": "Oh yeah, that was soooo cool!"}' \
	 --user admin:admin \
     --cacert ./deployments/nginx/certs/nginx.crt | python -m json.tool

