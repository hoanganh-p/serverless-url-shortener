using FluentAssertions;
using Microsoft.Extensions.Logging;
using Moq;
using UrlShortener.Application.Abstractions.Persistence;
using UrlShortener.Application.Abstractions.Security;
using UrlShortener.Application.Services;
using UrlShortener.Application.Services.Interfaces;
using UrlShortener.Domain.Entities;

namespace UrlShortener.Tests;

public class UrlServiceTests
{
    private readonly Mock<IUrlRepository> _mockRepository;
    private readonly Mock<ILogger<UrlService>> _mockLogger;
    private readonly UrlService _service;

    public UrlServiceTests()
    {
        _mockRepository = new Mock<IUrlRepository>();
        _mockLogger = new Mock<ILogger<UrlService>>();
        _service = new UrlService(_mockRepository.Object, _mockLogger.Object);
    }

    [Fact]
    public async Task CreateAsync_WithValidUrl_ShouldReturnShortUrl()
    {
        // Arrange
        var originalUrl = "https://example.com/some-path";
        _mockRepository.Setup(r => r.GetByShortCodeAsync(It.IsAny<string>()))
            .ReturnsAsync((ShortUrl?)null);

        // Act
        var result = await _service.CreateAsync(originalUrl);

        // Assert
        result.Should().NotBeNull();
        result.ShortCode.Should().HaveLength(7);
        result.OriginalUrl.Should().Be(originalUrl);
        result.IsActive.Should().BeTrue();
        result.TotalClicks.Should().Be(0);
        result.UserId.Should().BeNull();
        result.CreatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(5));

        _mockRepository.Verify(r => r.AddAsync(It.Is<ShortUrl>(u =>
            u.OriginalUrl == originalUrl &&
            u.ShortCode.Length == 7)), Times.Once);
    }

    [Fact]
    public async Task CreateAsync_WithValidUrlAndUserId_ShouldSetUserId()
    {
        // Arrange
        var originalUrl = "https://example.com";
        var userId = "user-123";
        _mockRepository.Setup(r => r.GetByShortCodeAsync(It.IsAny<string>()))
            .ReturnsAsync((ShortUrl?)null);

        // Act
        var result = await _service.CreateAsync(originalUrl, userId);

        // Assert
        result.UserId.Should().Be(userId);
    }

    [Fact]
    public async Task CreateAsync_WithInvalidUrl_ShouldThrowArgumentException()
    {
        // Act & Assert
        await _service.Invoking(s => s.CreateAsync("not-a-url"))
            .Should().ThrowAsync<ArgumentException>()
            .WithParameterName("originalUrl");
    }

    [Fact]
    public async Task CreateAsync_WithEmptyUrl_ShouldThrowArgumentException()
    {
        // Act & Assert
        await _service.Invoking(s => s.CreateAsync(""))
            .Should().ThrowAsync<ArgumentException>()
            .WithParameterName("originalUrl");
    }

    [Fact]
    public async Task CreateAsync_WithWhitespaceUrl_ShouldThrowArgumentException()
    {
        // Act & Assert
        await _service.Invoking(s => s.CreateAsync("   "))
            .Should().ThrowAsync<ArgumentException>()
            .WithParameterName("originalUrl");
    }

    [Fact]
    public async Task CreateAsync_WithUrlMissingScheme_ShouldThrowArgumentException()
    {
        // Act & Assert
        await _service.Invoking(s => s.CreateAsync("example.com"))
            .Should().ThrowAsync<ArgumentException>()
            .WithParameterName("originalUrl");
    }

    [Fact]
    public async Task CreateAsync_WhenCodeCollision_ShouldRetryAndSucceed()
    {
        // Arrange
        var originalUrl = "https://example.com";
        var callCount = 0;

        // Setup to return a collision on first call, then null on subsequent calls
        _mockRepository.Setup(r => r.GetByShortCodeAsync(It.IsAny<string>()))
            .Returns<string>(code =>
            {
                callCount++;
                if (callCount == 1)
                    return Task.FromResult<ShortUrl?>(new ShortUrl { ShortCode = code });
                return Task.FromResult<ShortUrl?>(null);
            });

        // Act
        var result = await _service.CreateAsync(originalUrl);

        // Assert
        result.Should().NotBeNull();
        callCount.Should().Be(2); // First call = collision, second call = success
        _mockRepository.Verify(r => r.AddAsync(It.IsAny<ShortUrl>()), Times.Once);
    }

    [Fact]
    public async Task CreateAsync_WhenMaxRetriesExceeded_ShouldThrowException()
    {
        // Arrange
        var originalUrl = "https://example.com";
        _mockRepository.Setup(r => r.GetByShortCodeAsync(It.IsAny<string>()))
            .ReturnsAsync(new ShortUrl { ShortCode = "existing" });

        // Act & Assert
        await _service.Invoking(s => s.CreateAsync(originalUrl))
            .Should().ThrowAsync<Exception>()
            .WithMessage("Failed to generate unique short code after retries.");
    }

    [Fact]
    public async Task GetAsync_WithExistingCode_ShouldReturnUrl()
    {
        // Arrange
        var shortCode = "abc1234";
        var expectedUrl = new ShortUrl
        {
            ShortCode = shortCode,
            OriginalUrl = "https://example.com",
            UserId = "user-1"
        };
        _mockRepository.Setup(r => r.GetByShortCodeAsync(shortCode))
            .ReturnsAsync(expectedUrl);

        // Act
        var result = await _service.GetAsync(shortCode);

        // Assert
        result.Should().BeEquivalentTo(expectedUrl);
    }

    [Fact]
    public async Task GetAsync_WithNonExistingCode_ShouldReturnNull()
    {
        // Arrange
        _mockRepository.Setup(r => r.GetByShortCodeAsync(It.IsAny<string>()))
            .ReturnsAsync((ShortUrl?)null);

        // Act
        var result = await _service.GetAsync("nonexistent");

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task GetUserUrlsAsync_WithValidUserId_ShouldReturnUserUrls()
    {
        // Arrange
        var userId = "user-1";
        var urls = new List<ShortUrl>
        {
            new ShortUrl { ShortCode = "abc1", OriginalUrl = "https://a.com", UserId = userId },
            new ShortUrl { ShortCode = "abc2", OriginalUrl = "https://b.com", UserId = userId }
        };
        _mockRepository.Setup(r => r.GetAllForUserAsync(userId))
            .ReturnsAsync(urls);

        // Act
        var result = await _service.GetUserUrlsAsync(userId);

        // Assert
        result.Should().HaveCount(2);
        result.Should().OnlyContain(u => u.UserId == userId);
    }

    [Fact]
    public async Task GetUserUrlsAsync_WithEmptyUserId_ShouldThrowArgumentException()
    {
        // Act & Assert
        await _service.Invoking(s => s.GetUserUrlsAsync(""))
            .Should().ThrowAsync<ArgumentException>()
            .WithParameterName("userId");
    }

    [Fact]
    public async Task GetUserUrlsAsync_WithNullUserId_ShouldThrowArgumentException()
    {
        // Act & Assert
        await _service.Invoking(s => s.GetUserUrlsAsync(null!))
            .Should().ThrowAsync<ArgumentException>()
            .WithParameterName("userId");
    }

    [Fact]
    public async Task GetUserUrlAsync_WithMatchingUser_ShouldReturnUrl()
    {
        // Arrange
        var shortCode = "abc123";
        var userId = "user-1";
        var url = new ShortUrl { ShortCode = shortCode, UserId = userId, OriginalUrl = "https://example.com" };
        _mockRepository.Setup(r => r.GetByShortCodeAsync(shortCode))
            .ReturnsAsync(url);

        // Act
        var result = await _service.GetUserUrlAsync(shortCode, userId);

        // Assert
        result.Should().BeEquivalentTo(url);
    }

    [Fact]
    public async Task GetUserUrlAsync_WithDifferentUser_ShouldReturnNull()
    {
        // Arrange
        var shortCode = "abc123";
        var url = new ShortUrl { ShortCode = shortCode, UserId = "other-user" };
        _mockRepository.Setup(r => r.GetByShortCodeAsync(shortCode))
            .ReturnsAsync(url);

        // Act
        var result = await _service.GetUserUrlAsync(shortCode, "user-1");

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task GetUserUrlAsync_WithEmptyShortCode_ShouldThrowArgumentException()
    {
        // Act & Assert
        await _service.Invoking(s => s.GetUserUrlAsync("", "user-1"))
            .Should().ThrowAsync<ArgumentException>()
            .WithParameterName("shortCode");
    }

    [Fact]
    public async Task UpdateAsync_WithValidData_ShouldUpdateAndReturnUrl()
    {
        // Arrange
        var shortCode = "abc123";
        var userId = "user-1";
        var originalUrl = new ShortUrl { ShortCode = shortCode, UserId = userId, OriginalUrl = "https://old.com" };
        var newUrl = "https://new-example.com";

        _mockRepository.Setup(r => r.GetByShortCodeAsync(shortCode))
            .ReturnsAsync(originalUrl);

        // Act
        var result = await _service.UpdateAsync(shortCode, newUrl, userId);

        // Assert
        result.Should().NotBeNull();
        result!.OriginalUrl.Should().Be(newUrl);
        _mockRepository.Verify(r => r.UpdateAsync(It.Is<ShortUrl>(u => u.OriginalUrl == newUrl)), Times.Once);
    }

    [Fact]
    public async Task UpdateAsync_WithInvalidUrl_ShouldThrowArgumentException()
    {
        // Act & Assert
        await _service.Invoking(s => s.UpdateAsync("code", "invalid", "user"))
            .Should().ThrowAsync<ArgumentException>()
            .WithParameterName("originalUrl");
    }

    [Fact]
    public async Task UpdateAsync_WithNonExistentUrl_ShouldReturnNull()
    {
        // Arrange
        _mockRepository.Setup(r => r.GetByShortCodeAsync(It.IsAny<string>()))
            .ReturnsAsync((ShortUrl?)null);

        // Act
        var result = await _service.UpdateAsync("nonexistent", "https://new.com", "user");

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task UpdateAsync_WithDifferentUser_ShouldReturnNull()
    {
        // Arrange
        var shortCode = "abc123";
        var url = new ShortUrl { ShortCode = shortCode, UserId = "other-user" };
        _mockRepository.Setup(r => r.GetByShortCodeAsync(shortCode))
            .ReturnsAsync(url);

        // Act
        var result = await _service.UpdateAsync(shortCode, "https://new.com", "user-1");

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task DeleteAsync_WithValidData_ShouldDeleteAndReturnTrue()
    {
        // Arrange
        var shortCode = "abc123";
        var userId = "user-1";
        var url = new ShortUrl { ShortCode = shortCode, UserId = userId };
        _mockRepository.Setup(r => r.GetByShortCodeAsync(shortCode))
            .ReturnsAsync(url);

        // Act
        var result = await _service.DeleteAsync(shortCode, userId);

        // Assert
        result.Should().BeTrue();
        _mockRepository.Verify(r => r.DeleteAsync(url), Times.Once);
    }

    [Fact]
    public async Task DeleteAsync_WithNonExistentUrl_ShouldReturnFalse()
    {
        // Arrange
        _mockRepository.Setup(r => r.GetByShortCodeAsync(It.IsAny<string>()))
            .ReturnsAsync((ShortUrl?)null);

        // Act
        var result = await _service.DeleteAsync("nonexistent", "user-1");

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task DeleteAsync_WithDifferentUser_ShouldReturnFalse()
    {
        // Arrange
        var url = new ShortUrl { ShortCode = "abc", UserId = "other-user" };
        _mockRepository.Setup(r => r.GetByShortCodeAsync("abc"))
            .ReturnsAsync(url);

        // Act
        var result = await _service.DeleteAsync("abc", "user-1");

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task IncrementClicksAsync_WithExistingUrl_ShouldIncrementAndReturnUrl()
    {
        // Arrange
        var shortCode = "abc123";
        var url = new ShortUrl { ShortCode = shortCode, TotalClicks = 5 };
        _mockRepository.Setup(r => r.GetByShortCodeAsync(shortCode))
            .ReturnsAsync(url);

        // Act
        var result = await _service.IncrementClicksAsync(shortCode);

        // Assert
        result.Should().NotBeNull();
        result!.TotalClicks.Should().Be(6);
        _mockRepository.Verify(r => r.UpdateAsync(It.Is<ShortUrl>(u => u.TotalClicks == 6)), Times.Once);
    }

    [Fact]
    public async Task IncrementClicksAsync_WithNonExistentUrl_ShouldReturnNull()
    {
        // Arrange
        _mockRepository.Setup(r => r.GetByShortCodeAsync(It.IsAny<string>()))
            .ReturnsAsync((ShortUrl?)null);

        // Act
        var result = await _service.IncrementClicksAsync("nonexistent");

        // Assert
        result.Should().BeNull();
    }
}

public class UserServiceTests
{
    private readonly Mock<IUserRepository> _mockRepository;
    private readonly Mock<IPasswordHasher> _mockPasswordHasher;
    private readonly UserService _service;

    public UserServiceTests()
    {
        _mockRepository = new Mock<IUserRepository>();
        _mockPasswordHasher = new Mock<IPasswordHasher>();
        _service = new UserService(_mockRepository.Object, _mockPasswordHasher.Object);
    }

    [Fact]
    public async Task CreateUserAsync_WithNewUser_ShouldHashPasswordAndSave()
    {
        // Arrange
        var user = new User
        {
            Username = "newuser",
            Email = "new@example.com",
            PasswordHash = "plainpassword"
        };
        _mockRepository.Setup(r => r.GetByUsernameAsync(user.Username))
            .ReturnsAsync((User?)null);
        _mockPasswordHasher.Setup(h => h.HashPassword(user.PasswordHash))
            .Returns("hashed-password");

        // Act
        var result = await _service.CreateUserAsync(user);

        // Assert
        result.Should().BeTrue();
        user.PasswordHash.Should().Be("hashed-password");
        user.UserId.Should().NotBeNullOrEmpty();
        user.CreatedAt.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromSeconds(5));
        user.IsActive.Should().BeTrue();
        user.Role.Should().Be("User");

        _mockRepository.Verify(r => r.SaveAsync(user), Times.Once);
    }

    [Fact]
    public async Task CreateUserAsync_WithExistingUsername_ShouldReturnFalse()
    {
        // Arrange
        var user = new User
        {
            Username = "existing",
            Email = "test@example.com",
            PasswordHash = "password"
        };
        _mockRepository.Setup(r => r.GetByUsernameAsync(user.Username))
            .ReturnsAsync(new User { Username = "existing" });

        // Act
        var result = await _service.CreateUserAsync(user);

        // Assert
        result.Should().BeFalse();
        _mockRepository.Verify(r => r.SaveAsync(It.IsAny<User>()), Times.Never);
    }

    [Fact]
    public async Task CreateUserAsync_WhenExceptionThrown_ShouldReturnFalse()
    {
        // Arrange
        var user = new User
        {
            Username = "newuser",
            Email = "test@example.com",
            PasswordHash = "password"
        };
        _mockRepository.Setup(r => r.GetByUsernameAsync(user.Username))
            .ReturnsAsync((User?)null);
        _mockRepository.Setup(r => r.SaveAsync(It.IsAny<User>()))
            .ThrowsAsync(new Exception("DB Error"));

        // Act
        var result = await _service.CreateUserAsync(user);

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task ValidateUserCredentialsAsync_WithValidCredentials_ShouldReturnTrue()
    {
        // Arrange
        var username = "alice";
        var password = "correct-password";
        var user = new User
        {
            Username = username,
            PasswordHash = "hashed-password",
            IsActive = true
        };
        _mockRepository.Setup(r => r.GetByUsernameAsync(username))
            .ReturnsAsync(user);
        _mockPasswordHasher.Setup(h => h.VerifyPassword(password, user.PasswordHash))
            .Returns(true);

        // Act
        var result = await _service.ValidateUserCredentialsAsync(username, password);

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public async Task ValidateUserCredentialsAsync_WithWrongPassword_ShouldReturnFalse()
    {
        // Arrange
        var username = "alice";
        var user = new User
        {
            Username = username,
            PasswordHash = "hashed-password",
            IsActive = true
        };
        _mockRepository.Setup(r => r.GetByUsernameAsync(username))
            .ReturnsAsync(user);
        _mockPasswordHasher.Setup(h => h.VerifyPassword("wrong-password", user.PasswordHash))
            .Returns(false);

        // Act
        var result = await _service.ValidateUserCredentialsAsync(username, "wrong-password");

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task ValidateUserCredentialsAsync_WithNonExistentUser_ShouldReturnFalse()
    {
        // Arrange
        _mockRepository.Setup(r => r.GetByUsernameAsync("nonexistent"))
            .ReturnsAsync((User?)null);

        // Act
        var result = await _service.ValidateUserCredentialsAsync("nonexistent", "password");

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task ValidateUserCredentialsAsync_WithInactiveUser_ShouldReturnFalse()
    {
        // Arrange
        var user = new User
        {
            Username = "inactive",
            PasswordHash = "hashed-password",
            IsActive = false
        };
        _mockRepository.Setup(r => r.GetByUsernameAsync("inactive"))
            .ReturnsAsync(user);

        // Act
        var result = await _service.ValidateUserCredentialsAsync("inactive", "password");

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public async Task GetUserByUsernameAsync_WithExistingUser_ShouldReturnUser()
    {
        // Arrange
        var user = new User { Username = "alice", Email = "alice@example.com" };
        _mockRepository.Setup(r => r.GetByUsernameAsync("alice"))
            .ReturnsAsync(user);

        // Act
        var result = await _service.GetUserByUsernameAsync("alice");

        // Assert
        result.Should().BeEquivalentTo(user);
    }

    [Fact]
    public async Task GetUserByUsernameAsync_WithNonExistentUser_ShouldReturnNull()
    {
        // Arrange
        _mockRepository.Setup(r => r.GetByUsernameAsync("nonexistent"))
            .ReturnsAsync((User?)null);

        // Act
        var result = await _service.GetUserByUsernameAsync("nonexistent");

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task GetUserByIdAsync_WithExistingId_ShouldReturnUser()
    {
        // Arrange
        var user = new User { UserId = "u1", Username = "alice" };
        _mockRepository.Setup(r => r.GetByIdAsync("u1"))
            .ReturnsAsync(user);

        // Act
        var result = await _service.GetUserByIdAsync("u1");

        // Assert
        result.Should().BeEquivalentTo(user);
    }

    [Fact]
    public async Task GetUserByIdAsync_WithNonExistentId_ShouldReturnNull()
    {
        // Arrange
        _mockRepository.Setup(r => r.GetByIdAsync("nonexistent"))
            .ReturnsAsync((User?)null);

        // Act
        var result = await _service.GetUserByIdAsync("nonexistent");

        // Assert
        result.Should().BeNull();
    }
}