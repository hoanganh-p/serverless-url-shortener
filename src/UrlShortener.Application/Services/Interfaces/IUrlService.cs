using UrlShortener.Domain.Entities;

namespace UrlShortener.Application.Services.Interfaces;

public interface IUrlService
{
    Task<ShortUrl> CreateAsync(string originalUrl, string? userId = null);
    Task<ShortUrl?> GetAsync(string shortCode);
    Task<IEnumerable<ShortUrl>> GetUserUrlsAsync(string userId);
    Task<ShortUrl?> UpdateAsync(string shortCode, string originalUrl, string userId);
    Task<bool> DeleteAsync(string shortCode, string userId);
    Task<ShortUrl?> GetUserUrlAsync(string shortCode, string userId);
    Task<ShortUrl?> IncrementClicksAsync(string shortCode);
}
