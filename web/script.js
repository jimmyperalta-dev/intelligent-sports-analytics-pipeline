// API endpoint configuration
const API_ENDPOINT = 'https://m0xrw4u6p6.execute-api.us-east-1.amazonaws.com/v1';

// DOM elements
const uploadArea = document.getElementById('uploadArea');
const fileInput = document.getElementById('fileInput');
const uploadStatus = document.getElementById('uploadStatus');
const searchButton = document.getElementById('searchButton');
const searchInput = document.getElementById('searchInput');
const searchType = document.getElementById('searchType');
const resultsContainer = document.getElementById('resultsContainer');

// Initialize event listeners
document.addEventListener('DOMContentLoaded', () => {
    setupUploadHandlers();
    setupSearchHandlers();
});

// Upload functionality
function setupUploadHandlers() {
    uploadArea.addEventListener('click', () => fileInput.click());
    
    uploadArea.addEventListener('dragover', (e) => {
        e.preventDefault();
        uploadArea.classList.add('drag-over');
    });
    
    uploadArea.addEventListener('dragleave', () => {
        uploadArea.classList.remove('drag-over');
    });
    
    uploadArea.addEventListener('drop', handleDrop);
    fileInput.addEventListener('change', handleFileSelect);
}

function handleDrop(e) {
    e.preventDefault();
    uploadArea.classList.remove('drag-over');
    
    const files = e.dataTransfer.files;
    if (files.length > 0) {
        handleFile(files[0]);
    }
}

function handleFileSelect(e) {
    const files = e.target.files;
    if (files.length > 0) {
        handleFile(files[0]);
    }
}

async function handleFile(file) {
    // Validate file type
    const validTypes = ['application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'text/plain'];
    if (!validTypes.includes(file.type)) {
        showUploadStatus('Please upload a PDF, DOCX, or TXT file.', 'error');
        return;
    }
    
    // Show uploading status
    showUploadStatus('Uploading document...', 'info');
    
    try {
        // Get presigned URL
        const response = await fetch(`${API_ENDPOINT}/documents/upload`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                filename: file.name,
                contentType: file.type
            })
        });
        
        const data = await response.json();
        
        if (!response.ok) {
            throw new Error(data.error || 'Upload failed');
        }
        
        // Upload to S3 using presigned URL
        const uploadResponse = await fetch(data.uploadUrl, {
            method: 'PUT',
            headers: {
                'Content-Type': file.type,
            },
            body: file
        });
        
        if (!uploadResponse.ok) {
            throw new Error('Failed to upload to S3');
        }
        
        showUploadStatus(`Document uploaded successfully! Document ID: ${data.documentId}`, 'success');
        
        // Poll for analysis results
        setTimeout(() => checkAnalysisStatus(data.documentId), 3000);
        
    } catch (error) {
        showUploadStatus(`Upload failed: ${error.message}`, 'error');
    }
}

function showUploadStatus(message, type) {
    uploadStatus.textContent = message;
    uploadStatus.className = `upload-status ${type}`;
    
    if (type === 'success' || type === 'error') {
        setTimeout(() => {
            uploadStatus.className = 'upload-status';
        }, 5000);
    }
}

// Search functionality
function setupSearchHandlers() {
    searchButton.addEventListener('click', performSearch);
    searchInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            performSearch();
        }
    });
}

async function performSearch() {
    const query = searchInput.value.trim();
    const type = searchType.value;
    
    if (!query && type === 'all') {
        showNoResults();
        return;
    }
    
    try {
        const params = new URLSearchParams({
            q: query,
            type: type
        });
        
        const response = await fetch(`${API_ENDPOINT}/search?${params}`);
        const data = await response.json();
        
        if (!response.ok) {
            throw new Error(data.error || 'Search failed');
        }
        
        displayResults(data.results);
        
    } catch (error) {
        console.error('Search error:', error);
        showNoResults();
    }
}

function displayResults(results) {
    if (!results || results.length === 0) {
        showNoResults();
        return;
    }
    
    const resultsHTML = results.map(result => `
        <div class="result-card">
            <h3>${result.title}</h3>
            <p class="result-excerpt">${result.excerpt}</p>
            <div class="result-meta">
                <span class="result-type">${formatDocType(result.type)}</span>
                <span class="result-date">${formatDate(result.date)}</span>
            </div>
        </div>
    `).join('');
    
    resultsContainer.innerHTML = resultsHTML;
}

function showNoResults() {
    resultsContainer.innerHTML = '<div class="no-results">No results found. Try a different search term.</div>';
}

// Analysis status checking
async function checkAnalysisStatus(documentId) {
    try {
        const response = await fetch(`${API_ENDPOINT}/documents/analyze?documentId=${documentId}`);
        const data = await response.json();
        
        if (data.status === 'completed') {
            showUploadStatus('Document analysis completed!', 'success');
            // Could display analysis results here
        } else {
            // Check again in a few seconds
            setTimeout(() => checkAnalysisStatus(documentId), 5000);
        }
    } catch (error) {
        console.error('Error checking analysis status:', error);
    }
}

// Utility functions
function formatDocType(type) {
    const typeMap = {
        'season_report': 'Season Report',
        'player_stats': 'Player Stats',
        'draft_report': 'Draft Report',
        'contract_news': 'Contract News',
        'stadium_report': 'Stadium Report'
    };
    return typeMap[type] || type;
}

function formatDate(dateString) {
    const date = new Date(dateString);
    const options = { year: 'numeric', month: 'short', day: 'numeric' };
    return date.toLocaleDateString('en-US', options);
}
