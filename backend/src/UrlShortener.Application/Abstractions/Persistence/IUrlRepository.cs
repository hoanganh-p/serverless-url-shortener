using UrlShortener.Domain.Entities;

namespace UrlShortener.Application.Abstractions.Persistence;

public interface IUrlRepository
{
    Task<ShortUrl?> GetByShortCodeAsync(string shortCode);
    Task AddAsync(ShortUrl url);
    Task<IEnumerable<ShortUrl>> GetAllForUserAsync(string userId);
    Task UpdateAsync(ShortUrl url);
    Task DeleteAsync(ShortUrl url);
}
