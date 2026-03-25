﻿using System.ComponentModel.DataAnnotations;

namespace UrlShortener.Api.DTOs
{
    public class CreateRequest
    {
        [Required]
        public string OriginalUrl { get; set; } = null!;
    }

    public class CreateResponse
    {
        public string ShortCode { get; set; } = null!;
        public string ShortUrl { get; set; } = null!;
    }

    public class UpdateUrlRequest
    {
        [Required]
        public string OriginalUrl { get; set; } = null!;
    }

    public class UrlResponse
    {
        public string ShortCode { get; set; } = null!;
        public string OriginalUrl { get; set; } = null!;
        public string ShortUrl { get; set; } = null!;
        public DateTime CreatedAt { get; set; }
        public bool IsActive { get; set; }
        public long TotalClicks { get; set; }
    }
}
