using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Logging;
using UrlShortener.Application.Abstractions.Persistence;
using UrlShortener.Application.Services.Interfaces;
using UrlShortener.Domain.Entities;

namespace UrlShortener.Application.Services;

public class UrlService : IUrlService
{
    private static readonly char[] Base62Chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray();
    private const int ShortCodeLength = 7;

    private readonly IUrlRepository _repository;
    private readonly ILogger<UrlService> _logger;

    public UrlService(IUrlRepository repository, ILogger<UrlService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<ShortUrl> CreateAsync(string originalUrl, string? userId = null)
    {
        if (!Uri.TryCreate(originalUrl, UriKind.Absolute, out _))
        {
            throw new ArgumentException("Invalid URL format", nameof(originalUrl));
        }

        originalUrl = originalUrl.Trim();

        var retries = 3;
        var code = string.Empty;

        while (retries > 0)
        {
            code = GenerateShortCode();
            var existing = await _repository.GetByShortCodeAsync(code);
            if (existing == null)
            {
                break;
            }

            retries--;
            if (retries == 0)
            {
                throw new Exception("Failed to generate unique short code after retries.");
            }
        }

        var url = new ShortUrl
        {
            ShortCode = code,
            OriginalUrl = originalUrl,
            UserId = userId,
            CreatedAt = DateTime.UtcNow,
            IsActive = true,
            TotalClicks = 0
        };

        try
        {
            await _repository.AddAsync(url);
            return url;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while saving URL.");
            throw;
        }
    }

    public Task<ShortUrl?> GetAsync(string shortCode)
    {
        return _repository.GetByShortCodeAsync(shortCode);
    }

    public async Task<IEnumerable<ShortUrl>> GetUserUrlsAsync(string userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new ArgumentException("UserId cannot be empty.", nameof(userId));
        }

        try
        {
            return await _repository.GetAllForUserAsync(userId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error while retrieving user URLs for userId: {UserId}", userId);
            throw;
        }
    }

    public async Task<ShortUrl?> GetUserUrlAsync(string shortCode, string userId)
    {
        if (string.IsNullOrWhiteSpace(shortCode))
        {
            throw new ArgumentException("ShortCode cannot be empty.", nameof(shortCode));
        }

        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new ArgumentException("UserId cannot be empty.", nameof(userId));
        }

        try
        {
            var url = await _repository.GetByShortCodeAsync(shortCode);
            if (url == null || url.UserId != userId)
            {
                return null;
            }

            return url;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error while retrieving URL for shortCode: {ShortCode}", shortCode);
            throw;
        }
    }

    public async Task<ShortUrl?> UpdateAsync(string shortCode, string originalUrl, string userId)
    {
        if (!Uri.TryCreate(originalUrl, UriKind.Absolute, out _))
        {
            throw new ArgumentException("Invalid URL format", nameof(originalUrl));
        }

        if (string.IsNullOrWhiteSpace(shortCode) || string.IsNullOrWhiteSpace(userId))
        {
            throw new ArgumentException("ShortCode and UserId cannot be empty.");
        }

        try
        {
            var url = await _repository.GetByShortCodeAsync(shortCode);
            if (url == null || url.UserId != userId)
            {
                return null;
            }

            url.OriginalUrl = originalUrl.Trim();
            await _repository.UpdateAsync(url);
            return url;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error while updating URL for shortCode: {ShortCode}", shortCode);
            throw;
        }
    }

    public async Task<bool> DeleteAsync(string shortCode, string userId)
    {
        if (string.IsNullOrWhiteSpace(shortCode) || string.IsNullOrWhiteSpace(userId))
        {
            throw new ArgumentException("ShortCode and UserId cannot be empty.");
        }

        try
        {
            var url = await _repository.GetByShortCodeAsync(shortCode);
            if (url == null || url.UserId != userId)
            {
                return false;
            }

            await _repository.DeleteAsync(url);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error while deleting URL for shortCode: {ShortCode}", shortCode);
            throw;
        }
    }

    public async Task<ShortUrl?> IncrementClicksAsync(string shortCode)
    {
        if (string.IsNullOrWhiteSpace(shortCode))
        {
            throw new ArgumentException("ShortCode cannot be empty.", nameof(shortCode));
        }

        try
        {
            var url = await _repository.GetByShortCodeAsync(shortCode);
            if (url == null)
            {
                return null;
            }

            url.TotalClicks++;
            await _repository.UpdateAsync(url);
            return url;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error while incrementing clicks for shortCode: {ShortCode}", shortCode);
            throw;
        }
    }

    private static string GenerateShortCode()
    {
        Span<byte> buffer = stackalloc byte[ShortCodeLength];
        RandomNumberGenerator.Fill(buffer);

        var builder = new StringBuilder(ShortCodeLength);
        for (var i = 0; i < ShortCodeLength; i++)
        {
            builder.Append(Base62Chars[buffer[i] % Base62Chars.Length]);
        }

        return builder.ToString();
    }
}
