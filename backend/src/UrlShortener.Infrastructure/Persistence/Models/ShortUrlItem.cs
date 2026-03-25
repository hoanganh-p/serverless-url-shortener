using Amazon.DynamoDBv2.DataModel;

namespace UrlShortener.Infrastructure.Persistence.Models;

[DynamoDBTable("Urls")]
public class ShortUrlItem
{
    [DynamoDBHashKey]
    public string ShortCode { get; set; } = string.Empty;

    [DynamoDBProperty]
    public string OriginalUrl { get; set; } = string.Empty;

    [DynamoDBProperty]
    public string? UserId { get; set; }

    [DynamoDBProperty]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [DynamoDBProperty]
    public bool IsActive { get; set; } = true;

    [DynamoDBProperty]
    public long TotalClicks { get; set; }
}
