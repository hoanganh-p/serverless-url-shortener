using UrlShortener.Domain.Entities;

namespace UrlShortener.Application.Abstractions.Persistence;

public interface IUserRepository
{
    Task<User?> GetByUsernameAsync(string username);
    Task<User?> GetByIdAsync(string userId);
    Task SaveAsync(User user);
}
