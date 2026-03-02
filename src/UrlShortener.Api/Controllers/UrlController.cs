using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using UrlShortener.Api.DTOs;
using UrlShortener.Application.Services.Interfaces;
using UrlShortener.Domain.Entities;

namespace UrlShortener.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class UrlController : ControllerBase
{
    private readonly IUrlService _urlService;
    private readonly ILogger<UrlController> _logger;

    public UrlController(IUrlService urlService, ILogger<UrlController> logger)
    {
        _urlService = urlService;
        _logger = logger;
    }

    [HttpPost("create")]
    [ProducesResponseType(typeof(CreateResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> CreateShortUrl([FromBody] CreateRequest req)
    {
        if (!Uri.IsWellFormedUriString(req.OriginalUrl, UriKind.Absolute))
        {
            return BadRequest("Invalid URL");
        }

        var userId = GetUserId();
        var created = await _urlService.CreateAsync(req.OriginalUrl, userId);

        var response = ToCreateResponse(created);
        return CreatedAtAction(nameof(RedirectToOriginal), new { code = created.ShortCode }, response);
    }

    [HttpGet("{code}")]
    [ProducesResponseType(StatusCodes.Status302Found)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> RedirectToOriginal(string code)
    {
        var data = await _urlService.GetAsync(code);
        if (data == null)
        {
            return NotFound();
        }

        await _urlService.IncrementClicksAsync(code);
        return Redirect(data.OriginalUrl);
    }

    [HttpGet("user/all")]
    [Authorize]
    [ProducesResponseType(typeof(IEnumerable<UrlResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetUserUrls()
    {
        var userId = GetUserId();
        if (string.IsNullOrWhiteSpace(userId))
        {
            return Unauthorized("User not authenticated");
        }

        try
        {
            var urls = await _urlService.GetUserUrlsAsync(userId);
            return Ok(urls.Select(ToUrlResponse));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving user URLs");
            return StatusCode(500, "Error retrieving URLs");
        }
    }

    [HttpGet("{code}/details")]
    [Authorize]
    [ProducesResponseType(typeof(UrlResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetUrlDetails(string code)
    {
        var userId = GetUserId();
        if (string.IsNullOrWhiteSpace(userId))
        {
            return Unauthorized("User not authenticated");
        }

        try
        {
            var url = await _urlService.GetUserUrlAsync(code, userId);
            if (url == null)
            {
                return NotFound("URL not found or you don't have access");
            }

            return Ok(ToUrlResponse(url));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving URL details");
            return StatusCode(500, "Error retrieving URL details");
        }
    }

    [HttpPut("{code}")]
    [Authorize]
    [ProducesResponseType(typeof(UrlResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateUrl(string code, [FromBody] UpdateUrlRequest req)
    {
        if (!Uri.IsWellFormedUriString(req.OriginalUrl, UriKind.Absolute))
        {
            return BadRequest("Invalid URL");
        }

        var userId = GetUserId();
        if (string.IsNullOrWhiteSpace(userId))
        {
            return Unauthorized("User not authenticated");
        }

        try
        {
            var updated = await _urlService.UpdateAsync(code, req.OriginalUrl, userId);
            if (updated == null)
            {
                return NotFound("URL not found or you don't have access");
            }

            return Ok(ToUrlResponse(updated));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating URL");
            return StatusCode(500, "Error updating URL");
        }
    }

    [HttpDelete("{code}")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteUrl(string code)
    {
        var userId = GetUserId();
        if (string.IsNullOrWhiteSpace(userId))
        {
            return Unauthorized("User not authenticated");
        }

        try
        {
            var deleted = await _urlService.DeleteAsync(code, userId);
            if (!deleted)
            {
                return NotFound("URL not found or you don't have access");
            }

            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting URL");
            return StatusCode(500, "Error deleting URL");
        }
    }

    private string? GetUserId()
    {
        return User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
    }

    private string GetBaseUrl()
    {
        return $"{Request.Scheme}://{Request.Host}";
    }

    private CreateResponse ToCreateResponse(ShortUrl url)
    {
        return new CreateResponse
        {
            ShortCode = url.ShortCode,
            ShortUrl = $"{GetBaseUrl()}/{url.ShortCode}"
        };
    }

    private UrlResponse ToUrlResponse(ShortUrl url)
    {
        return new UrlResponse
        {
            ShortCode = url.ShortCode,
            OriginalUrl = url.OriginalUrl,
            ShortUrl = $"{GetBaseUrl()}/{url.ShortCode}",
            CreatedAt = url.CreatedAt,
            IsActive = url.IsActive,
            TotalClicks = url.TotalClicks
        };
    }
}
