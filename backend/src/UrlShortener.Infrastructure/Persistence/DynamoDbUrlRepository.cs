using Amazon.DynamoDBv2.DataModel;
using Amazon.DynamoDBv2.DocumentModel;
using UrlShortener.Application.Abstractions.Persistence;
using UrlShortener.Domain.Entities;
using UrlShortener.Infrastructure.Persistence.Models;

namespace UrlShortener.Infrastructure.Persistence;

public class DynamoDbUrlRepository : IUrlRepository
{
    private readonly IDynamoDBContext _db;

    public DynamoDbUrlRepository(IDynamoDBContext db)
    {
        _db = db;
    }

    public async Task<ShortUrl?> GetByShortCodeAsync(string shortCode)
    {
        var item = await _db.LoadAsync<ShortUrlItem>(shortCode);
        return item?.ToDomain();
    }

    public Task AddAsync(ShortUrl url)
    {
        return _db.SaveAsync(url.ToItem());
    }

    public async Task<IEnumerable<ShortUrl>> GetAllForUserAsync(string userId)
    {
        var conditions = new List<ScanCondition>
        {
            new ScanCondition(nameof(ShortUrlItem.UserId), ScanOperator.Equal, userId)
        };

        var search = _db.ScanAsync<ShortUrlItem>(conditions);
        var items = await search.GetRemainingAsync();

        return items
            .Select(x => x.ToDomain())
            .OrderByDescending(x => x.CreatedAt);
    }

    public Task UpdateAsync(ShortUrl url)
    {
        return _db.SaveAsync(url.ToItem());
    }

    public Task DeleteAsync(ShortUrl url)
    {
        return _db.DeleteAsync(url.ToItem());
    }
}
