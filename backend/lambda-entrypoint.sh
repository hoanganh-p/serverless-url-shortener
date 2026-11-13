#!/bin/bash
# Lambda entrypoint script for ASP.NET Core on AWS Lambda

set -euo pipefail

# Enable X-Ray if configured
if [ -n "${AWS_XRAY_DAEMON_ADDRESS:-}" ]; then
    echo "Starting X-Ray daemon..."
    # Start X-Ray daemon in background
    /usr/bin/xray -o -b "${AWS_XRAY_DAEMON_ADDRESS}" &
    XRAY_PID=$!
    # Trap to kill X-Ray daemon on exit
    trap "kill $XRAY_PID 2>/dev/null || true" EXIT
fi

# Use AWS Lambda Runtime Interface Emulator (RIE) for local testing
# In actual Lambda, the runtime provides this automatically
if [ -n "${AWS_LAMBDA_RUNTIME_API:-}" ]; then
    # Running in actual Lambda - use the built-in runtime
    exec /usr/bin/dotnet UrlShortener.Api.dll "$@"
else
    # Running locally - use RIE
    if [ -f "/var/runtime/aws-lambda-rie" ]; then
        exec /var/runtime/aws-lambda-rie /usr/bin/dotnet UrlShortener.Api.dll "$@"
    else
        echo "AWS_LAMBDA_RUNTIME_API not set and RIE not found. Running in direct mode..."
        exec /usr/bin/dotnet UrlShortener.Api.dll "$@"
    fi
fi