using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using System.ComponentModel.DataAnnotations;
using UrlShortener.Api.DTOs;
using UrlShortener.Application.Abstractions.Security;
using UrlShortener.Application.Options;
using UrlShortener.Application.Services.Interfaces;
using UrlShortener.Domain.Entities;

namespace UrlShortener.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IJwtService _jwtService;
    private readonly IUserService _userService;
    private readonly JwtOptions _jwtOptions;

    public AuthController(IJwtService jwtService, IUserService userService, IOptions<JwtOptions> jwtOptions)
    {
        _jwtService = jwtService;
        _userService = userService;
        _jwtOptions = jwtOptions.Value;
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrWhiteSpace(request.Password))
        {
            return BadRequest(new { message = "Username and password are required" });
        }

        var isValid = await _userService.ValidateUserCredentialsAsync(request.Username, request.Password);
        if (!isValid)
        {
            return Unauthorized(new { message = "Invalid username or password" });
        }

        var user = await _userService.GetUserByUsernameAsync(request.Username);
        if (user == null)
        {
            return Unauthorized(new { message = "User not found" });
        }

        var token = _jwtService.GenerateToken(
            userId: user.UserId,
            username: user.Username,
            roles: new[] { user.Role });

        return Ok(new LoginResponse
        {
            Token = token,
            Username = user.Username,
            ExpiresAt = DateTime.UtcNow.AddMinutes(_jwtOptions.ExpirationInMinutes)
        });
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Username) ||
            string.IsNullOrWhiteSpace(request.Password) ||
            string.IsNullOrWhiteSpace(request.Email))
        {
            return BadRequest(new { message = "Username, password, and email are required" });
        }

        if (request.Password.Length < 6)
        {
            return BadRequest(new { message = "Password must be at least 6 characters" });
        }

        if (!new EmailAddressAttribute().IsValid(request.Email))
        {
            return BadRequest(new { message = "Invalid email format" });
        }

        var user = new User
        {
            Username = request.Username,
            Email = request.Email,
            PasswordHash = request.Password,
            Role = "User"
        };

        var success = await _userService.CreateUserAsync(user);
        if (!success)
        {
            return Conflict(new { message = "Username or email already exists" });
        }

        return StatusCode(StatusCodes.Status201Created, new { message = "User registered successfully", userId = user.UserId });
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<IActionResult> GetCurrentUser()
    {
        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrWhiteSpace(userId))
        {
            return Unauthorized();
        }

        var user = await _userService.GetUserByIdAsync(userId);
        if (user == null)
        {
            return NotFound(new { message = "User not found" });
        }

        return Ok(new
        {
            userId = user.UserId,
            username = user.Username,
            email = user.Email,
            role = user.Role,
            createdAt = user.CreatedAt
        });
    }
}
