using Amazon.DynamoDBv2.DataModel;

namespace UrlShortener.Infrastructure.Persistence.Models;

[DynamoDBTable("Users")]
public class UserItem
{
    [DynamoDBHashKey]
    public string UserId { get; set; } = string.Empty;

    [DynamoDBProperty]
    public string Username { get; set; } = string.Empty;

    [DynamoDBProperty]
    public string PasswordHash { get; set; } = string.Empty;

    [DynamoDBProperty]
    public string Email { get; set; } = string.Empty;

    [DynamoDBProperty]
    public string Role { get; set; } = "User";

    [DynamoDBProperty]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [DynamoDBProperty]
    public bool IsActive { get; set; } = true;
}
