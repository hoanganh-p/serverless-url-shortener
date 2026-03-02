using Microsoft.Extensions.Logging.Abstractions;
using UrlShortener.Application.Abstractions.Persistence;
using UrlShortener.Application.Abstractions.Security;
using UrlShortener.Application.Services;
using UrlShortener.Domain.Entities;

namespace UrlShortener.Tests;

public class ApplicationServicesTests
{
    [Fact]
    public async Task UrlService_CreateAsync_ShouldPersistShortUrl()
    {
        var repository = new InMemoryUrlRepository();
        var service = new UrlService(repository, NullLogger<UrlService>.Instance);

        var result = await service.CreateAsync("https://example.com/some-path");

        Assert.False(string.IsNullOrWhiteSpace(result.ShortCode));
        Assert.Equal(7, result.ShortCode.Length);
        Assert.Equal("https://example.com/some-path", result.OriginalUrl);
        Assert.NotNull(await repository.GetByShortCodeAsync(result.ShortCode));
    }

    [Fact]
    public async Task UserService_ValidateUserCredentialsAsync_ShouldReturnTrue_ForValidPassword()
    {
        var repository = new InMemoryUserRepository();
        var passwordHasher = new FakePasswordHasher();
        var service = new UserService(repository, passwordHasher);

        await repository.SaveAsync(new User
        {
            UserId = "u1",
            Username = "alice",
            PasswordHash = passwordHasher.HashPassword("123456"),
            Email = "alice@example.com",
            Role = "User",
            IsActive = true
        });

        var isValid = await service.ValidateUserCredentialsAsync("alice", "123456");

        Assert.True(isValid);
    }

    private sealed class InMemoryUrlRepository : IUrlRepository
    {
        private readonly Dictionary<string, ShortUrl> _store = new();

        public Task<ShortUrl?> GetByShortCodeAsync(string shortCode)
        {
            _store.TryGetValue(shortCode, out var url);
            return Task.FromResult(url);
        }

        public Task AddAsync(ShortUrl url)
        {
            _store[url.ShortCode] = url;
            return Task.CompletedTask;
        }

        public Task<IEnumerable<ShortUrl>> GetAllForUserAsync(string userId)
        {
            var urls = _store.Values.Where(x => x.UserId == userId).AsEnumerable();
            return Task.FromResult(urls);
        }

        public Task UpdateAsync(ShortUrl url)
        {
            _store[url.ShortCode] = url;
            return Task.CompletedTask;
        }

        public Task DeleteAsync(ShortUrl url)
        {
            _store.Remove(url.ShortCode);
            return Task.CompletedTask;
        }
    }

    private sealed class InMemoryUserRepository : IUserRepository
    {
        private readonly Dictionary<string, User> _usersById = new();

        public Task<User?> GetByUsernameAsync(string username)
        {
            var user = _usersById.Values.FirstOrDefault(x => x.Username == username);
            return Task.FromResult(user);
        }

        public Task<User?> GetByIdAsync(string userId)
        {
            _usersById.TryGetValue(userId, out var user);
            return Task.FromResult(user);
        }

        public Task SaveAsync(User user)
        {
            _usersById[user.UserId] = user;
            return Task.CompletedTask;
        }
    }

    private sealed class FakePasswordHasher : IPasswordHasher
    {
        public string HashPassword(string password)
        {
            return $"hashed::{password}";
        }

        public bool VerifyPassword(string password, string passwordHash)
        {
            return HashPassword(password) == passwordHash;
        }
    }
}
