#!/bin/bash

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Initialize a failure flag
TESTS_FAILED=0

# Function to print a test result
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "[${GREEN}PASS${NC}] $2"
    else
        echo -e "[${RED}FAIL${NC}] $2"
        TESTS_FAILED=1
    fi
}

# --- Test 1: Nominal Prediction (API v1) ---
echo "
--- Running Test 1: Nominal Prediction (API v1) ---"
response_v1=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://localhost/predict" \
     -H "Content-Type: application/json" \
     -d '{"sentence": "Oh yeah, that was soooo cool!"}' \
     --user admin:admin \
     --cacert ./deployments/nginx/certs/nginx.crt)

if [ "$response_v1" -eq 200 ]; then
    print_result 0 "API v1 returned HTTP 200 OK."
else
    print_result 1 "API v1 returned HTTP $response_v1 instead of 200."
fi

# --- Test 2: A/B Routing (API v2) ---
echo "
--- Running Test 2: A/B Routing (API v2) ---"
response_v2_body=$(curl -s -X POST "https://localhost/predict" \
     -H "Content-Type: application/json" \
     -H "X-Experiment-Group: debug" \
     -d '{"sentence": "Oh yeah, that was soooo cool!"}' \
     --user admin:admin \
     --cacert ./deployments/nginx/certs/nginx.crt)

if echo "$response_v2_body" | grep -q 'prediction_proba_dict'; then
    print_result 0 "API v2 response contains 'prediction_proba_dict'."
else
    print_result 1 "API v2 response does not contain 'prediction_proba_dict'."
fi

# --- Test 3: Authentication Failure ---
echo "
--- Running Test 3: Authentication Failure ---"
response_auth=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://localhost/predict" \
     -H "Content-Type: application/json" \
     -d '{"sentence": "test"}' \
     --user admin:wrongpassword \
     --cacert ./deployments/nginx/certs/nginx.crt)

if [ "$response_auth" -eq 401 ]; then
    print_result 0 "Authentication failed with incorrect credentials as expected (HTTP 401)."
else
    print_result 1 "Authentication test returned HTTP $response_auth instead of 401."
fi

# --- Test 4: Rate Limiting (Burst Protection) ---
echo "
--- Running Test 4.1: Rate Limiting (Burst Protection) ---"
# Send 25 rapid requests to trigger rate limiting (limit is 10r/s + burst of 2)
echo "Sending 25 rapid requests to test rate limiting (limit: 10 req/s per IP)..."
blocked_count=0
success_count=0

for i in {1..25}; do
    status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://localhost/predict" \
         -H "Content-Type: application/json" \
         -d '{"sentence": "rate limit test"}' \
         --user admin:admin \
         --cacert ./deployments/nginx/certs/nginx.crt 2>/dev/null)
    
    # Rate limiting returns 503 (Service Unavailable) when limit exceeded
    if [ "$status" -eq 503 ] || [ "$status" -eq 429 ]; then
        blocked_count=$((blocked_count + 1))
    elif [ "$status" -eq 200 ]; then
        success_count=$((success_count + 1))
    fi
done

echo "Results: $success_count succeeded, $blocked_count blocked (out of 25 requests)"

# We expect at least 10 requests to be blocked (demonstrating rate limiting)
# With rate=10r/s and burst=2, only ~12 requests should succeed when sent rapidly
if [ "$blocked_count" -ge 10 ]; then
    print_result 0 "Rate limiting blocks excessive burst traffic ($blocked_count requests blocked, $success_count succeeded)."
else
    print_result 1 "Rate limiting is NOT working properly (only $blocked_count blocked, expected at least 10)."
fi

# --- Test 4.5: Rate Limiting (Within Limit) ---
echo "
--- Running Test 4.2: Rate Limiting (Within Limit) ---"
# Send 20 requests over 2 seconds (exactly 10 req/s) to verify traffic within limit is allowed
echo "Sending 20 requests over 2 seconds (10 req/s - within rate limit)..."
within_limit_blocked=0
within_limit_success=0

for i in {1..20}; do
    status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://localhost/predict" \
         -H "Content-Type: application/json" \
         -d '{"sentence": "within limit test"}' \
         --user admin:admin \
         --cacert ./deployments/nginx/certs/nginx.crt 2>/dev/null)
    
    if [ "$status" -eq 503 ] || [ "$status" -eq 429 ]; then
        within_limit_blocked=$((within_limit_blocked + 1))
    elif [ "$status" -eq 200 ]; then
        within_limit_success=$((within_limit_success + 1))
    fi
    
    # Sleep 0.1 seconds between requests (10 requests/second)
    sleep 0.11
done

echo "Results: $within_limit_success succeeded, $within_limit_blocked blocked (out of 20 requests)"

# When staying within the rate limit, we expect all or nearly all requests to succeed
if [ "$within_limit_success" -ge 18 ]; then
    print_result 0 "Rate limiting allows legitimate traffic within limits ($within_limit_success/20 succeeded)."
else
    print_result 1 "Rate limiting is blocking legitimate traffic (only $within_limit_success/20 succeeded, expected >= 18)."
fi


# --- Test 5: Prometheus Availability ---
echo "
--- Running Test 5: Prometheus Availability ---"
response_prometheus=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/api/v1/status/runtimeinfo)

if [ "$response_prometheus" -eq 200 ]; then
    print_result 0 "Prometheus is available (HTTP 200)."
else
    print_result 1 "Prometheus is not available (HTTP $response_prometheus)."
fi

# --- Test 6: Grafana Availability ---
echo "
--- Running Test 6: Grafana Availability ---"
response_grafana=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health)

if [ "$response_grafana" -eq 200 ]; then
    print_result 0 "Grafana is available (HTTP 200)."
else
    print_result 1 "Grafana is not available (HTTP $response_grafana)."
fi

# --- Final Result ---
echo
if [ $TESTS_FAILED -eq 1 ]; then
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed successfully!${NC}"
    exit 0
fi