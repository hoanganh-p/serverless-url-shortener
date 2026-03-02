using UrlShortener.Application.Abstractions.Persistence;
using UrlShortener.Application.Abstractions.Security;
using UrlShortener.Application.Services.Interfaces;
using UrlShortener.Domain.Entities;

namespace UrlShortener.Application.Services;

public class UserService : IUserService
{
    private readonly IUserRepository _repository;
    private readonly IPasswordHasher _passwordHasher;

    public UserService(IUserRepository repository, IPasswordHasher passwordHasher)
    {
        _repository = repository;
        _passwordHasher = passwordHasher;
    }

    public Task<User?> GetUserByUsernameAsync(string username)
    {
        return _repository.GetByUsernameAsync(username);
    }

    public Task<User?> GetUserByIdAsync(string userId)
    {
        return _repository.GetByIdAsync(userId);
    }

    public async Task<bool> CreateUserAsync(User user)
    {
        try
        {
            var existingUser = await _repository.GetByUsernameAsync(user.Username);
            if (existingUser != null)
            {
                return false;
            }

            user.UserId = Guid.NewGuid().ToString();
            user.CreatedAt = DateTime.UtcNow;
            user.PasswordHash = _passwordHasher.HashPassword(user.PasswordHash);

            await _repository.SaveAsync(user);
            return true;
        }
        catch
        {
            return false;
        }
    }

    public async Task<bool> ValidateUserCredentialsAsync(string username, string password)
    {
        var user = await _repository.GetByUsernameAsync(username);
        if (user == null || !user.IsActive)
        {
            return false;
        }

        return _passwordHasher.VerifyPassword(password, user.PasswordHash);
    }
}
