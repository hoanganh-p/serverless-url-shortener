using Microsoft.Extensions.DependencyInjection;
using UrlShortener.Application.Services;
using UrlShortener.Application.Services.Interfaces;

namespace UrlShortener.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<IUserService, UserService>();
        services.AddScoped<IUrlService, UrlService>();
        return services;
    }
}
