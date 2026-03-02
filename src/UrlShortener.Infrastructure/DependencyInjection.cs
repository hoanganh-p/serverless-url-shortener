using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.DataModel;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using UrlShortener.Application.Abstractions.Persistence;
using UrlShortener.Application.Abstractions.Security;
using UrlShortener.Infrastructure.Persistence;
using UrlShortener.Infrastructure.Security;

namespace UrlShortener.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDefaultAWSOptions(configuration.GetAWSOptions());
        services.AddAWSService<IAmazonDynamoDB>();

        services.AddScoped<IDynamoDBContext>(provider =>
        {
            var client = provider.GetRequiredService<IAmazonDynamoDB>();
            var config = new DynamoDBContextConfig
            {
                Conversion = DynamoDBEntryConversion.V2
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
