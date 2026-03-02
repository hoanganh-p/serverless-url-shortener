using System.ComponentModel.DataAnnotations;

namespace UrlShortener.Application.Options;

public class JwtOptions
{
    public const string SectionName = "JwtSettings";

    [Required]
    public string Secret { get; set; } = string.Empty;

    [Required]
    public string Issuer { get; set; } = string.Empty;

    [Required]
    public string Audience { get; set; } = string.Empty;

    [Range(1, 24 * 60)]
    public int ExpirationInMinutes { get; set; } = 60;
}
