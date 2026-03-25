import React from 'react';

function ResultDisplay({ result }) {
  if (!result) return null;

  return (
    <div className="result">
      <p>
        Short URL:{' '}
        <a href={result.shortUrl} target="_blank" rel="noopener noreferrer">
          {result.shortUrl}
        </a>
      </p>
    </div>
  );
}

export default ResultDisplay;
