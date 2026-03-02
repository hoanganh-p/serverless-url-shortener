using UrlShortener.Domain.Entities;

namespace UrlShortener.Application.Services.Interfaces;

public interface IUserService
{
    Task<User?> GetUserByUsernameAsync(string username);
    Task<User?> GetUserByIdAsync(string userId);
    Task<bool> CreateUserAsync(User user);
    Task<bool> ValidateUserCredentialsAsync(string username, string password);
}
