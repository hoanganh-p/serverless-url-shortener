using Amazon.DynamoDBv2.DataModel;
using Amazon.DynamoDBv2.DocumentModel;
using UrlShortener.Application.Abstractions.Persistence;
using UrlShortener.Domain.Entities;
using UrlShortener.Infrastructure.Persistence.Models;

namespace UrlShortener.Infrastructure.Persistence;

public class DynamoDbUserRepository : IUserRepository
{
    private readonly IDynamoDBContext _db;

    public DynamoDbUserRepository(IDynamoDBContext db)
    {
        _db = db;
    }

    public async Task<User?> GetByUsernameAsync(string username)
    {
        var search = _db.ScanAsync<UserItem>(
            new[]
            {
                new ScanCondition(nameof(UserItem.Username), ScanOperator.Equal, username)
            },
            new DynamoDBOperationConfig { OverrideTableName = UserItem.TableName });

        var users = await search.GetNextSetAsync();
        return users.FirstOrDefault()?.ToDomain();
    }

    public async Task<User?> GetByIdAsync(string userId)
    {
        var item = await _db.LoadAsync<UserItem>(userId, new DynamoDBOperationConfig { OverrideTableName = UserItem.TableName });
        return item?.ToDomain();
    }

    public Task SaveAsync(User user)
    {
        return _db.SaveAsync(user.ToItem(), new DynamoDBOperationConfig { OverrideTableName = UserItem.TableName });
    }
}