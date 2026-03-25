namespace UrlShortener.Application.Abstractions.Security;

public interface IJwtService
{
    string GenerateToken(string userId, string username, IEnumerable<string>? roles = null);
}
