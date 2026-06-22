/* ==========================================================================
   Weather Dashboard Logic (Open-Meteo API & Lucide Icons)
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {
  // DOM Elements
  const searchInput = document.getElementById('search-input');
  const searchForm = document.getElementById('search-form');
  const clearSearchBtn = document.getElementById('clear-search-btn');
  const geolocationBtn = document.getElementById('geolocation-btn');
  const suggestionsDropdown = document.getElementById('suggestions-dropdown');
  const suggestionsList = document.getElementById('suggestions-list');

  // Display sections
  const loadingSkeleton = document.getElementById('loading-skeleton');
  const errorCard = document.getElementById('error-card');
  const weatherDashboardContent = document.getElementById('weather-dashboard-content');
  const errorRetryBtn = document.getElementById('error-retry-btn');

  // Current weather elements
  const cityNameEl = document.getElementById('weather-city-name');
  const countryNameEl = document.getElementById('weather-country-name');
  const dateEl = document.getElementById('weather-date');
  const tempValueEl = document.getElementById('weather-temp-value');
  const tempMaxEl = document.getElementById('weather-temp-max');
  const tempMinEl = document.getElementById('weather-temp-min');
  const conditionDescEl = document.getElementById('weather-condition-desc');
  const mainIconContainer = document.getElementById('weather-main-icon-container');

  // Metrics elements
  const metricFeelsLikeEl = document.getElementById('metric-feels-like');
  const metricHumidityEl = document.getElementById('metric-humidity');
  const metricHumiditySubEl = document.getElementById('metric-humidity-sub');
  const metricWindEl = document.getElementById('metric-wind');
  const metricWindDirEl = document.getElementById('metric-wind-dir');
  const metricCloudsEl = document.getElementById('metric-clouds');
  const metricVisibilityEl = document.getElementById('metric-visibility');
  const metricPressureEl = document.getElementById('metric-pressure');

  // Forecast elements
  const hourlyForecastContainer = document.getElementById('hourly-forecast-container');
  const weeklyForecastList = document.getElementById('weekly-forecast-list');

  // State Management
  let debounceTimeout = null;
  let lastSuccessfulLocation = null;

  // WMO Weather Interpretation Codes (WMO 4680)
  const wmoCodes = {
    0: { desc: 'Clear sky', icon: 'sun', theme: 'theme-clear' },
    1: { desc: 'Mainly clear', icon: 'cloud-sun', theme: 'theme-clear' },
    2: { desc: 'Partly cloudy', icon: 'cloud-sun', theme: 'theme-cloudy' },
    3: { desc: 'Overcast', icon: 'cloud', theme: 'theme-cloudy' },
    45: { desc: 'Foggy', icon: 'cloud-fog', theme: 'theme-cloudy' },
    48: { desc: 'Depositing rime fog', icon: 'cloud-fog', theme: 'theme-cloudy' },
    51: { desc: 'Light drizzle', icon: 'cloud-drizzle', theme: 'theme-rainy' },
    53: { desc: 'Moderate drizzle', icon: 'cloud-drizzle', theme: 'theme-rainy' },
    55: { desc: 'Dense drizzle', icon: 'cloud-drizzle', theme: 'theme-rainy' },
    56: { desc: 'Light freezing drizzle', icon: 'cloud-snow', theme: 'theme-snowy' },
    57: { desc: 'Dense freezing drizzle', icon: 'cloud-snow', theme: 'theme-snowy' },
    61: { desc: 'Slight rain', icon: 'cloud-rain', theme: 'theme-rainy' },
    63: { desc: 'Moderate rain', icon: 'cloud-rain', theme: 'theme-rainy' },
    65: { desc: 'Heavy rain', icon: 'cloud-rain-wind', theme: 'theme-rainy' },
    66: { desc: 'Light freezing rain', icon: 'cloud-snow', theme: 'theme-snowy' },
    67: { desc: 'Heavy freezing rain', icon: 'cloud-snow', theme: 'theme-snowy' },
    71: { desc: 'Slight snow fall', icon: 'snowflake', theme: 'theme-snowy' },
    73: { desc: 'Moderate snow fall', icon: 'snowflake', theme: 'theme-snowy' },
    75: { desc: 'Heavy snow fall', icon: 'snowflake', theme: 'theme-snowy' },
    77: { desc: 'Snow grains', icon: 'snowflake', theme: 'theme-snowy' },
    80: { desc: 'Slight rain showers', icon: 'cloud-drizzle', theme: 'theme-rainy' },
    81: { desc: 'Moderate rain showers', icon: 'cloud-rain', theme: 'theme-rainy' },
    82: { desc: 'Violent rain showers', icon: 'cloud-rain-wind', theme: 'theme-rainy' },
    85: { desc: 'Slight snow showers', icon: 'cloud-snow', theme: 'theme-snowy' },
    86: { desc: 'Heavy snow showers', icon: 'cloud-snow', theme: 'theme-snowy' },
    95: { desc: 'Thunderstorm', icon: 'cloud-lightning', theme: 'theme-stormy' },
    96: { desc: 'Thunderstorm with slight hail', icon: 'cloud-lightning', theme: 'theme-stormy' },
    99: { desc: 'Thunderstorm with heavy hail', icon: 'cloud-lightning', theme: 'theme-stormy' }
  };

  // Helper: Get WMO Weather details
  function getWmoDetails(code) {
    return wmoCodes[code] || { desc: 'Unknown weather', icon: 'help-circle', theme: 'theme-cloudy' };
  }

  // Helper: Convert degrees to cardinal wind direction
  function getWindDirectionCard(degrees) {
    const directions = ['North (N)', 'North-East (NE)', 'East (E)', 'South-East (SE)', 'South (S)', 'South-West (SW)', 'West (W)', 'North-West (NW)'];
    const idx = Math.round(((degrees % 360) / 45)) % 8;
    return directions[idx];
  }

  // Helper: Format Date
  function formatDate(dateString) {
    const options = { weekday: 'long', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' };
    return new Date(dateString).toLocaleDateString('en-US', options);
  }

  // Helper: Get weekday name
  function getWeekdayName(dateString) {
    const date = new Date(dateString);
    const today = new Date();
    
    if (date.toDateString() === today.toDateString()) {
      return 'Today';
    }
    
    return date.toLocaleDateString('en-US', { weekday: 'long' });
  }

  // Debounced input handler for geocoding autocomplete
  searchInput.addEventListener('input', () => {
    const query = searchInput.value.trim();
    
    // Toggle clear search button visibility
    clearSearchBtn.style.display = query.length > 0 ? 'flex' : 'none';

    clearTimeout(debounceTimeout);

    if (query.length < 2) {
      hideSuggestions();
      return;
    }

    debounceTimeout = setTimeout(() => {
      fetchSuggestions(query);
    }, 300);
  });

  // Clear search input action
  clearSearchBtn.addEventListener('click', () => {
    searchInput.value = '';
    clearSearchBtn.style.display = 'none';
    searchInput.focus();
    hideSuggestions();
  });

  // Close suggestions on outside click
  document.addEventListener('click', (e) => {
    if (!searchForm.contains(e.target) && !suggestionsDropdown.contains(e.target)) {
      hideSuggestions();
    }
  });

  // Autocomplete fetch using Fetch API with error handling
  async function fetchSuggestions(query) {
    try {
      if (!navigator.onLine) {
        throw new Error('Offline');
      }

      const response = await fetch(`https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(query)}&count=5&language=en&format=json`);
      
      if (!response.ok) {
        throw new Error(`HTTP Error: ${response.status}`);
      }

      const data = await response.json();
      
      if (!data.results || data.results.length === 0) {
        hideSuggestions();
        return;
      }

      renderSuggestions(data.results);
    } catch (error) {
      console.warn('Geocoding fetch suggestions failed:', error);
      // Fail silently for inline autocomplete, letting standard form submission do the error heavy lifting.
    }
  }

  // Render suggestions dropdown
  function renderSuggestions(cities) {
    suggestionsList.innerHTML = '';
    
    cities.forEach(city => {
      const li = document.createElement('li');
      
      // Construct descriptive text
      const region = city.admin1 ? `${city.admin1}, ` : '';
      const displayLocation = `${city.name}, ${region}${city.country}`;
      
      li.innerHTML = `<i data-lucide="map-pin"></i> <span>${displayLocation}</span>`;
      
      li.addEventListener('click', () => {
        searchInput.value = city.name;
        clearSearchBtn.style.display = 'flex';
        hideSuggestions();
        fetchWeather(city.latitude, city.longitude, city.name, city.country);
      });
      
      suggestionsList.appendChild(li);
    });
    
    suggestionsDropdown.style.display = 'block';
    lucide.createIcons();
  }

  function hideSuggestions() {
    suggestionsDropdown.style.display = 'none';
    suggestionsList.innerHTML = '';
  }

  // Intercept search submit to retrieve first result of query
  searchForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const query = searchInput.value.trim();
    if (!query) return;

    hideSuggestions();
    showLoading();

    try {
      if (!navigator.onLine) {
        throw new Error('Offline');
      }

      const response = await fetch(`https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(query)}&count=1&language=en&format=json`);
      
      if (!response.ok) {
        throw new Error(`HTTP Error: ${response.status}`);
      }

      const data = await response.json();
      
      if (!data.results || data.results.length === 0) {
        showError('Location Not Found', `We couldn't find any location named "${query}". Please check spelling and try again.`);
        return;
      }

      const city = data.results[0];
      fetchWeather(city.latitude, city.longitude, city.name, city.country);
    } catch (error) {
      handleAppError(error);
    }
  });

  // Handle Geolocation API
  geolocationBtn.addEventListener('click', () => {
    if (!navigator.geolocation) {
      showError('Geolocation Unsupported', 'Your browser does not support checking your physical location.');
      return;
    }

    showLoading();

    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const { latitude, longitude } = position.coords;
        let cityName = 'Current Location';
        let countryName = 'Your Area';

        // Attempt reverse geocoding via OpenStreetMap Nominatim
        try {
          if (navigator.onLine) {
            const response = await fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${latitude}&lon=${longitude}`, {
              headers: {
                'User-Agent': 'AtmosphericGlassWeatherDashboard/1.0'
              }
            });
            if (response.ok) {
              const data = await response.json();
              cityName = data.address.city || data.address.town || data.address.village || data.address.suburb || cityName;
              countryName = data.address.country || countryName;
            }
          }
        } catch (err) {
          console.warn('Reverse geocoding failed, falling back to placeholders:', err);
        }

        fetchWeather(latitude, longitude, cityName, countryName);
      },
      (error) => {
        console.error('Geolocation lookup failed:', error);
        let errorMsg = 'Access to geolocation was denied. Please input city name manually.';
        if (error.code === error.POSITION_UNAVAILABLE) {
          errorMsg = 'Location information is currently unavailable.';
        } else if (error.code === error.TIMEOUT) {
          errorMsg = 'The request to get your location timed out.';
        }
        showError('Location Access Failed', errorMsg);
      },
      { timeout: 10000 }
    );
  });

  // Core weather fetch operation
  async function fetchWeather(lat, lon, cityName, countryName) {
    showLoading();

    try {
      if (!navigator.onLine) {
        throw new Error('Offline');
      }

      // Fetch current, hourly, and daily metrics from Open-Meteo
      const weatherUrl = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,visibility&hourly=temperature_2m,precipitation_probability,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto`;
      
      const response = await fetch(weatherUrl);
      
      if (!response.ok) {
        throw new Error(`HTTP Error: ${response.status}`);
      }

      const data = await response.json();
      
      // Parse, cache, and render
      lastSuccessfulLocation = { lat, lon, cityName, countryName };
      localStorage.setItem('saved_weather_location', JSON.stringify(lastSuccessfulLocation));

      renderWeatherData(data, cityName, countryName);
    } catch (error) {
      handleAppError(error);
    }
  }

  // Parse nested JSON and render components
  function renderWeatherData(data, cityName, country) {
    const current = data.current;
    const hourly = data.hourly;
    const daily = data.daily;

    // Apply adaptive design theme based on current weather code
    const wmo = getWmoDetails(current.weather_code);
    document.body.className = wmo.theme;

    // Render Current Weather
    cityNameEl.textContent = cityName;
    countryNameEl.textContent = country;
    dateEl.textContent = formatDate(current.time);
    tempValueEl.textContent = Math.round(current.temperature_2m);
    tempMaxEl.textContent = `${Math.round(daily.temperature_2m_max[0])}°`;
    tempMinEl.textContent = `${Math.round(daily.temperature_2m_min[0])}°`;
    conditionDescEl.textContent = wmo.desc;

    // Inject SVG weather hero icon
    mainIconContainer.innerHTML = `<i id="weather-main-icon" data-lucide="${wmo.icon}" class="weather-hero-icon"></i>`;

    // Render Detailed Metrics Grid
    metricFeelsLikeEl.textContent = Math.round(current.apparent_temperature);
    metricHumidityEl.textContent = Math.round(current.relative_humidity_2m);
    
    // Custom moisture rating descriptor
    let humidityRating = 'Dry air';
    if (current.relative_humidity_2m > 70) {
      humidityRating = 'Very humid air';
    } else if (current.relative_humidity_2m >= 40) {
      humidityRating = 'Comfortable moisture';
    }
    metricHumiditySubEl.textContent = humidityRating;

    metricWindEl.textContent = Math.round(current.wind_speed_10m);
    metricWindDirEl.textContent = `Dir: ${getWindDirectionCard(current.wind_direction_10m)}`;
    metricCloudsEl.textContent = Math.round(current.cloud_cover);
    metricVisibilityEl.textContent = (current.visibility / 1000).toFixed(1); // M to KM
    metricPressureEl.textContent = Math.round(current.pressure_msl);

    // Render Hourly Slider (First 24 hours starting from current time alignment)
    hourlyForecastContainer.innerHTML = '';
    const nowHour = new Date(current.time).getHours();
    
    // We grab 24 sequential hourly slots starting from current hour
    for (let i = nowHour; i < nowHour + 24; i++) {
      if (i >= hourly.time.length) break;

      const timeVal = new Date(hourly.time[i]);
      const hourlyHour = timeVal.toLocaleTimeString('en-US', { hour: 'numeric', hour12: true });
      const tempVal = Math.round(hourly.temperature_2m[i]);
      const popVal = hourly.precipitation_probability[i];
      const hourlyWmo = getWmoDetails(hourly.weather_code[i]);

      const hourlyCard = document.createElement('div');
      hourlyCard.className = 'hourly-item';
      
      hourlyCard.innerHTML = `
        <span class="hourly-time">${hourlyHour}</span>
        <div class="hourly-icon-container">
          <i data-lucide="${hourlyWmo.icon}" class="hourly-icon"></i>
        </div>
        <span class="hourly-temp">${tempVal}°</span>
        <span class="hourly-pop" style="opacity: ${popVal > 0 ? 1 : 0}">
          <i data-lucide="droplet" style="width: 10px; height: 10px;"></i>${popVal}%
        </span>
      `;
      
      hourlyForecastContainer.appendChild(hourlyCard);
    }

    // Render 7-Day Forecast list
    weeklyForecastList.innerHTML = '';
    for (let i = 0; i < daily.time.length; i++) {
      const dayName = getWeekdayName(daily.time[i]);
      const maxT = Math.round(daily.temperature_2m_max[i]);
      const minT = Math.round(daily.temperature_2m_min[i]);
      const dailyWmo = getWmoDetails(daily.weather_code[i]);

      const weeklyRow = document.createElement('div');
      weeklyRow.className = 'weekly-item';
      weeklyRow.innerHTML = `
        <span class="weekly-day">${dayName}</span>
        <div class="weekly-condition">
          <i data-lucide="${dailyWmo.icon}" class="weekly-icon"></i>
          <span>${dailyWmo.desc}</span>
        </div>
        <div class="weekly-temp-range">
          <span class="weekly-max">${maxT}°</span>
          <span class="weekly-min">${minT}°</span>
        </div>
      `;

      weeklyForecastList.appendChild(weeklyRow);
    }

    // Unveil components and trigger icons replacement
    showDashboard();
    lucide.createIcons();
  }

  // Handle errors elegantly
  function handleAppError(error) {
    console.error('Weather dashboard error occurred:', error);
    if (error.message === 'Offline') {
      showError('Network Connection Lost', 'You appear to be offline. Please check your internet connection settings and try again.');
    } else {
      showError('Failed to Connect', 'An error occurred while contacting the weather service servers. Please try again shortly.');
    }
  }

  // Visual Transitions & View Control
  function showLoading() {
    loadingSkeleton.style.display = 'flex';
    errorCard.style.display = 'none';
    weatherDashboardContent.style.display = 'none';
  }

  function showDashboard() {
    loadingSkeleton.style.display = 'none';
    errorCard.style.display = 'none';
    weatherDashboardContent.style.display = 'grid';
    weatherDashboardContent.classList.remove('fade-in');
    void weatherDashboardContent.offsetWidth; // Trigger reflow for animation restart
    weatherDashboardContent.classList.add('fade-in');
  }

  function showError(title, message) {
    loadingSkeleton.style.display = 'none';
    weatherDashboardContent.style.display = 'none';
    
    document.getElementById('error-title').textContent = title;
    document.getElementById('error-message').textContent = message;
    errorCard.style.display = 'block';
    
    errorCard.classList.remove('fade-in');
    void errorCard.offsetWidth;
    errorCard.classList.add('fade-in');
    
    lucide.createIcons();
  }

  // Retry event listener on error card
  errorRetryBtn.addEventListener('click', () => {
    if (lastSuccessfulLocation) {
      fetchWeather(
        lastSuccessfulLocation.lat,
        lastSuccessfulLocation.lon,
        lastSuccessfulLocation.cityName,
        lastSuccessfulLocation.countryName
      );
    } else {
      // Fetch default location
      fetchWeather(40.7128, -74.0060, 'New York', 'United States');
    }
  });

  // Initialization: Load last city or fallback to default (New York)
  const savedLocation = localStorage.getItem('saved_weather_location');
  if (savedLocation) {
    try {
      const loc = JSON.parse(savedLocation);
      fetchWeather(loc.lat, loc.lon, loc.cityName, loc.countryName);
    } catch (e) {
      console.warn('Failed to parse cached location, falling back:', e);
      fetchWeather(40.7128, -74.0060, 'New York', 'United States');
    }
  } else {
    // Default location: New York
    fetchWeather(40.7128, -74.0060, 'New York', 'United States');
  }
});
