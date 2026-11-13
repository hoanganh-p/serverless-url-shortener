# ============================================================
# Multi-stage Dockerfile for AWS Lambda (Container Image)
# ============================================================

# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy csproj files first for better layer caching
COPY UrlShortener.sln .
COPY src/UrlShortener.Api/UrlShortener.Api.csproj src/UrlShortener.Api/
COPY src/UrlShortener.Application/UrlShortener.Application.csproj src/UrlShortener.Application/
COPY src/UrlShortener.Domain/UrlShortener.Domain.csproj src/UrlShortener.Domain/
COPY src/UrlShortener.Infrastructure/UrlShortener.Infrastructure.csproj src/UrlShortener.Infrastructure/
COPY tests/UrlShortener.UnitTests/UrlShortener.UnitTests.csproj tests/UrlShortener.UnitTests/

RUN dotnet restore UrlShortener.sln

# Copy source and build
COPY . .
RUN dotnet publish src/UrlShortener.Api/UrlShortener.Api.csproj -c Release -o /app/publish --no-restore

# Runtime stage - Use AWS Lambda base image for .NET
FROM public.ecr.aws/lambda/dotnet:10

# Set working directory
WORKDIR /var/task

# Copy published app
COPY --from=build /app/publish .

# Copy lambda entrypoint script
COPY lambda-entrypoint.sh /lambda-entrypoint.sh
RUN chmod +x /lambda-entrypoint.sh

# Set entry point for Lambda
ENTRYPOINT ["/lambda-entrypoint.sh"]

# Default command (can be overridden)
CMD ["UrlShortener.Api::UrlShortener.Api.LambdaEntryPoint::FunctionHandlerAsync"]