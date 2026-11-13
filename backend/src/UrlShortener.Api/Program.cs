using Amazon.Lambda.AspNetCoreServer.Hosting;
using Amazon.SecretsManager;
using Amazon.SecretsManager.Model;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using System.Text.Json;
using System.Threading.RateLimiting;
using UrlShortener.Application;
using UrlShortener.Application.Options;
using UrlShortener.Application.Services.Interfaces;
using UrlShortener.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

// Load JWT secret from AWS Secrets Manager in production
var jwtSecretArn = builder.Configuration["JWT_SECRET_ARN"];
var jwtSecret = builder.Configuration["JwtSettings__Secret"];

if (!string.IsNullOrEmpty(jwtSecretArn) && string.IsNullOrEmpty(jwtSecret))
{
    try
    {
        using var secretsClient = new AmazonSecretsManagerClient();
        var response = await secretsClient.GetSecretValueAsync(new GetSecretValueRequest
        {
            SecretId = jwtSecretArn
        });

        if (!string.IsNullOrEmpty(response.SecretString))
        {
            var secretJson = JsonSerializer.Deserialize<JsonElement>(response.SecretString);
            if (secretJson.TryGetProperty("SecretKey", out var secretKey))
            {
                jwtSecret = secretKey.GetString();
                builder.Configuration["JwtSettings__Secret"] = jwtSecret;
            }
            if (secretJson.TryGetProperty("Issuer", out var issuer))
            {
                builder.Configuration["JwtSettings__Issuer"] = issuer.GetString();
            }
            if (secretJson.TryGetProperty("Audience", out var audience))
            {
                builder.Configuration["JwtSettings__Audience"] = audience.GetString();
            }
            if (secretJson.TryGetProperty("ExpirationInMinutes", out var exp))
            {
                builder.Configuration["JwtSettings__ExpirationInMinutes"] = exp.GetString();
            }
        }
    }
    catch (Exception ex)
    {
        var logger = builder.Services.BuildServiceProvider().GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "Failed to retrieve JWT secret from Secrets Manager");
    }
}

builder.Services.AddOptions<JwtOptions>()
    .Bind(builder.Configuration.GetSection(JwtOptions.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();

var jwtOptions = builder.Configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>();
if (jwtOptions is null)
{
    throw new InvalidOperationException("JwtOptions configuration section is missing.");
}

if (string.IsNullOrWhiteSpace(jwtOptions.Secret))
{
    throw new InvalidOperationException("JwtOptions.Secret is missing. Set JwtSettings__Secret or JWT_SECRET_ARN.");
}

builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);

// Add AWS Lambda hosting (works for both Lambda and local)
builder.Services.AddAWSLambdaHosting(LambdaEventSource.HttpApi);

builder.Services
    .AddAuthentication(options =>
    {
        options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
        options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
        options.DefaultScheme = JwtBearerDefaults.AuthenticationScheme;
    })
    .AddJwtBearer(options =>
    {
        options.SaveToken = true;
        options.RequireHttpsMetadata = false; // API Gateway handles TLS termination
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidAudience = jwtOptions.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.Secret)),
            ClockSkew = TimeSpan.Zero
        };
    });

builder.Services.AddCors(options =>
{
    options.AddPolicy(
        "AllowCors",
        policy =>
        {
            var allowedOrigins = builder.Configuration["AllowedOrigins"] ?? "*";
            if (allowedOrigins == "*")
            {
                policy.AllowAnyOrigin()
                    .AllowAnyHeader()
                    .AllowAnyMethod();
            }
            else
            {
                policy.WithOrigins(allowedOrigins.Split(','))
                    .AllowAnyHeader()
                    .AllowAnyMethod()
                    .AllowCredentials();
            }
        });
});

builder.Services.AddAuthorization();
builder.Services.AddControllers();
builder.Services.AddHealthChecks();

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddFixedWindowLimiter("fixed", policy =>
    {
        policy.PermitLimit = 100;
        policy.Window = TimeSpan.FromMinutes(1);
        policy.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        policy.QueueLimit = 2;
    });
});

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto | ForwardedHeaders.XForwardedHost;
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
});

// Add custom metrics for CloudWatch
builder.Services.AddSingleton<UrlShortenerMetrics>();

var app = builder.Build();

// Global exception handler
app.UseExceptionHandler(errorApp =>
{
    errorApp.Run(async context =>
    {
        var exceptionHandlerPathFeature = context.Features.Get<IExceptionHandlerPathFeature>();
        var exception = exceptionHandlerPathFeature?.Error;

        var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
        logger.LogError(exception, "Unhandled exception");

        context.Response.StatusCode = 500;
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsJsonAsync(new { message = "An unexpected error occurred." });
    });
});

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}

app.UseForwardedHeaders();
app.UseCors("AllowCors");
// Don't use HTTPS redirection in Lambda (API Gateway handles TLS)
// app.UseHttpsRedirection();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHealthChecks("/health");

app.MapGet("/", () => "URL Shortener API Running");

app.MapGet("/{code}", async (string code, IUrlService urlService, ILogger<Program> logger, UrlShortenerMetrics metrics) =>
{
    logger.LogInformation("Redirect request received for code: {Code}", code);

    var data = await urlService.GetAsync(code);
    if (data == null)
    {
        return Results.NotFound();
    }

    await urlService.IncrementClicksAsync(code);
    metrics.RecordRedirect();
    return Results.Redirect(data.OriginalUrl);
})
.RequireRateLimiting("fixed");

app.Run();

// Lambda entry point for container image
public class LambdaEntryPoint : APIGatewayHttpApiV2ProxyFunction
{
    protected override void Init(IWebHostBuilder builder)
    {
        builder.UseStartup<Startup>();
    }
}

// Startup class for Lambda
public class Startup
{
    public void ConfigureServices(IServiceCollection services)
    {
        // Services are configured in Program.cs via top-level statements
        // This class exists for LambdaEntryPoint compatibility
    }

    public void Configure(IApplicationBuilder app)
    {
        // Pipeline is configured in Program.cs
    }
}

// Simple metrics class for custom CloudWatch metrics
public class UrlShortenerMetrics
{
    private readonly ILogger<UrlShortenerMetrics> _logger;

    public UrlShortenerMetrics(ILogger<UrlShortenerMetrics> logger)
    {
        _logger = logger;
    }

    public void RecordUrlCreated()
    {
        _logger.LogInformation("METRIC UrlsCreated 1 Count");
    }

    public void RecordRedirect()
    {
        _logger.LogInformation("METRIC Redirects 1 Count");
    }

    public void RecordCreationError()
    {
        _logger.LogInformation("METRIC UrlCreationErrors 1 Count");
    }
}