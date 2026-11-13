using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.DataModel;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using UrlShortener.Application.Abstractions.Persistence;
using UrlShortener.Application.Abstractions.Security;
using UrlShortener.Infrastructure.Persistence;
using UrlShortener.Infrastructure.Persistence.Models;
using UrlShortener.Infrastructure.Security;

namespace UrlShortener.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDefaultAWSOptions(configuration.GetAWSOptions());
        services.AddAWSService<IAmazonDynamoDB>();

        // Get table names from environment variables (set by Terraform)
        var usersTableName = configuration["DYNAMODB_USERS_TABLE"] ?? "Users";
        var urlsTableName = configuration["DYNAMODB_URLS_TABLE"] ?? "Urls";

        // Set static table names on model classes
        UserItem.TableName = usersTableName;
        ShortUrlItem.TableName = urlsTableName;

        services.AddScoped<IDynamoDBContext>(provider =>
        {
            var client = provider.GetRequiredService<IAmazonDynamoDB>();
            var config = new DynamoDBContextConfig
            {
                Conversion = DynamoDBEntryConversion.V2,
                // Use consistent reads for better consistency
                ConsistentRead = true
            };
#pragma warning disable CS0618
            return new DynamoDBContext(client, config);
#pragma warning restore CS0618
        });

        services.AddScoped<IUserRepository, DynamoDbUserRepository>();
        services.AddScoped<IUrlRepository, DynamoDbUrlRepository>();
        services.AddScoped<IPasswordHasher, BcryptPasswordHasher>();
        services.AddScoped<IJwtService, JwtService>();

        return services;
    }
}