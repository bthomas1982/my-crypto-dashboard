// script.js

const cmcApiKey = 'c9a08ac4-6a4d-4fd7-9232-5f13da7ef6b7'; // Replace with your CoinMarketCap API key
const newsApiKey = 'd9c33e81cfa04b72b8b951cd73666aea'; // Replace with your News API key

// Fetch live crypto prices from CoinMarketCap
async function fetchCryptoPrices() {
    try {
        console.log('Fetching crypto prices...');
        const response = await axios.get('https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest', {
            headers: {
                'X-CMC_PRO_API_KEY': cmcApiKey
            },
            params: {
                start: '1',
                limit: '10', // Change this to fetch more cryptocurrencies
                convert: 'USD'
            }
        });
        console.log('Prices fetched:', response.data);
        const prices = response.data.data;
        const ticker = document.querySelector('.ticker');
        ticker.innerHTML = '';
        prices.forEach(crypto => {
            ticker.innerHTML += `${crypto.name} (${crypto.symbol}): $${crypto.quote.USD.price.toFixed(2)} | `;
        });
    } catch (error) {
        console.error('Error fetching crypto prices:', error);
    }
}

// Fetch Bitcoin price chart data
async function fetchBitcoinChart() {
    try {
        console.log('Fetching Bitcoin chart data...');
        const response = await axios.get('https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=1&interval=hourly');
        console.log('Chart data fetched:', response.data);
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
                    fill: false,
                    pointRadius: 0,
                }]
            },
            options: {
                scales: {
                    x: {
                        type: 'time',
                        time: {
                            unit: 'hour',
                            tooltipFormat: 'MMM DD, hA',
                            displayFormats: {
                                hour: 'MMM DD, hA'
                            }
                        },
                        ticks: {
                            color: '#ffffff'
                        },
                        grid: {
                            display: false
                        }
                    },
                    y: {
                        ticks: {
                            color: '#ffffff'
                        },
                        grid: {
                            color: '#444444'
                        }
                    }
                },
                plugins: {
                    legend: {
                        labels: {
                            color: '#ffffff'
                        }
                    }
                },
                responsive: true,
                maintainAspectRatio: false,
            }
        });
    } catch (error) {
        console.error('Error fetching Bitcoin chart data:', error);
    }
}

// Fetch latest crypto market news
async function fetchCryptoNews() {
    try {
        console.log('Fetching crypto news...');
        const response = await axios.get(`https://newsapi.org/v2/everything?q=cryptocurrency&apiKey=${newsApiKey}`);
        console.log('News fetched:', response.data);
        const articles = response.data.articles;
        const newsFeed = document.getElementById('newsFeed');
        newsFeed.innerHTML = ''; // Clear previous news
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
