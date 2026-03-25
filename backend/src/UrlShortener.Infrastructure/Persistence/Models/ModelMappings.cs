using UrlShortener.Domain.Entities;

namespace UrlShortener.Infrastructure.Persistence.Models;

internal static class ModelMappings
{
    public static User ToDomain(this UserItem item)
    {
        return new User
        {
            UserId = item.UserId,
            Username = item.Username,
            PasswordHash = item.PasswordHash,
            Email = item.Email,
            Role = item.Role,
            CreatedAt = item.CreatedAt,
            IsActive = item.IsActive
        };
    }

    public static UserItem ToItem(this User user)
    {
        return new UserItem
        {
            UserId = user.UserId,
            Username = user.Username,
            PasswordHash = user.PasswordHash,
            Email = user.Email,
            Role = user.Role,
            CreatedAt = user.CreatedAt,
            IsActive = user.IsActive
        };
    }

    public static ShortUrl ToDomain(this ShortUrlItem item)
    {
        return new ShortUrl
        {
            ShortCode = item.ShortCode,
            OriginalUrl = item.OriginalUrl,
            UserId = item.UserId,
            CreatedAt = item.CreatedAt,
            IsActive = item.IsActive,
            TotalClicks = item.TotalClicks
        };
    }

    public static ShortUrlItem ToItem(this ShortUrl url)
    {
        return new ShortUrlItem
        {
            ShortCode = url.ShortCode,
            OriginalUrl = url.OriginalUrl,
            UserId = url.UserId,
            CreatedAt = url.CreatedAt,
            IsActive = url.IsActive,
            TotalClicks = url.TotalClicks
        };
    }
}
