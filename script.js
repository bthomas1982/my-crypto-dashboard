// script.js

// Fetch live crypto prices
async function fetchCryptoPrices() {
    try {
        const response = await axios.get('https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=usd');
        const prices = response.data;
        document.querySelector('.ticker').innerText = `BTC: $${prices.bitcoin.usd} | ETH: $${prices.ethereum.usd}`;
    } catch (error) {
        console.error('Error fetching crypto prices:', error);
    }
}

// Fetch Bitcoin price chart data
async function fetchBitcoinChart() {
    try {
        const response = await axios.get('https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=1&interval=hourly');
        const data = response.data.prices.map(price => ({
            x: new Date(price[0]),
            y: price[1]
        }));
        const ctx = document.getElementById('bitcoinChart').getContext('2d');
        new Chart(ctx, {
            type: 'line',
            data: {
                datasets: [{
                    label: 'Bitcoin Price (USD)',
                    data: data,
                    borderColor: 'rgba(75, 192, 192, 1)',
                    borderWidth: 1,
                    fill: false
                }]
            },
            options: {
                scales: {
                    x: {
                        type: 'time',
                        time: {
                            unit: 'hour'
                        }
                    },
                    y: {
                        beginAtZero: false
                    }
                }
            }
        });
    } catch (error) {
        console.error('Error fetching Bitcoin chart data:', error);
    }
}

// Fetch latest crypto market news
async function fetchCryptoNews() {
    try {
        const response = await axios.get('https://newsapi.org/v2/everything?q=crypto&apiKey=YOUR_NEWS_API_KEY');
        const articles = response.data.articles;
        const newsFeed = document.getElementById('newsFeed');
        articles.forEach(article => {
            const newsItem = document.createElement('div');
            newsItem.className = 'news-item';
            newsItem.innerHTML = `
                <h3><a href="${article.url}" target="_blank">${article.title}</a></h3>
                <p>${article.description}</p>
            `;
            newsFeed.appendChild(newsItem);
        });
    } catch (error) {
        console.error('Error fetching crypto news:', error);
    }
}

// Initialize the dashboard
fetchCryptoPrices();
fetchBitcoinChart();
fetchCryptoNews();
setInterval(fetchCryptoPrices, 60000); // Update prices every minute
