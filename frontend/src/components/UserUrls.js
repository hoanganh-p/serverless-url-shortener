import React from 'react';
import '../styles/UserUrls.css';

const UserUrls = ({ urls, onDelete }) => {
  if (!urls || urls.length === 0) {
    return <p className="no-links">You have no shortened links.</p>;
  }

  return (
    <div className="history-wrapper">
      <h2 className="history-title">Shortening History</h2>
      <table className="history-table">
        <thead>
          <tr className="history-header-row">
            <th className="history-th">Original URL</th>
            <th className="history-th">Short URL</th>
            <th className="history-th">Clicks</th>
            <th className="history-th">Created Date</th>
            <th className="history-th" style={{ textAlign: 'center' }}>Actions</th>
          </tr>
        </thead>
        <tbody>
          {urls.map((url, index) => (
            <tr key={index} className="history-row">
              <td className="history-td history-td-url" title={url.originalUrl}>
                <a href={url.originalUrl} target="_blank" rel="noopener noreferrer" className="history-link">
                  {url.originalUrl}
                </a>
              </td>
              <td className="history-td">
                <a href={url.shortUrl} target="_blank" rel="noopener noreferrer" className="history-short-link">
                  {url.shortUrl}
                </a>
              </td>
              <td className="history-td">{url.totalClicks}</td>
              <td className="history-td">{new Date(url.createdAt).toLocaleDateString('en-US')}</td>
              <td className="history-action-td">
                <button 
                  onClick={() => onDelete(url.shortCode)}
                  className="btn-delete"
                >
                  Delete
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default UserUrls;