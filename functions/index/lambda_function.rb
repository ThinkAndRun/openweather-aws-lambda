def lambda_handler(event:, context:)
  html_body = <<HTML
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Get Current Weather</title>
    <script>
        function getCurrentWeather() {
            var city = document.getElementById("input_field").value;
            var resultLabel = document.getElementById("result_label");
            var resultTextarea = document.getElementById("result");
            fetch(window.location.href + "/v1/getCurrentWeather/?city=" + city)
                .then(function(response) {
                    return response.json();
                })
                .then(function(data) {
                    if ("error_message" in data) {
                        resultLabel.innerHTML = "Error: " + data.error_message;
                        resultTextarea.value = "";
                    } else {
                        resultLabel.innerHTML = "Results for " + data.city + ":";
                        var formattedData = "Temperature: " + data.temperature + " °C\\n";
                        formattedData += "Weather conditions: " + data.weatherCondition.type + "\\n\\n";
                        formattedData += "Wind: " + data.wind.speed + " km/h\\n";
                        formattedData += "Wind direction: " + data.wind.direction + "\\n";
                        formattedData += "Pressure: " + data.weatherCondition.pressure + "\\n";
                        formattedData += "Humidity: " + data.weatherCondition.humidity + "\\n";

                        resultTextarea.value = formattedData;
                    }
                })
                .catch(function(error) {
                    resultLabel.innerHTML = "Error: " + error;
                    resultTextarea.value = "";
                    console.error("Error fetching weather data:", error);
                });
        }
    </script>
</head>
<body>
<h1>Current Weather</h1>
<form>
    <label for="input_field">City:</label>
    <input type="text" id="input_field" name="input_field" required>
    <input type="button" value="Search" onclick="getCurrentWeather()">
    <br>
    <br>
    <label id="result_label" for="result">Weather Data:</label>
    <br>
    <textarea id="result" name="result" rows="10" cols="50" readonly></textarea>
</form>
</body>
</html>
HTML

  {
    statusCode: 200,
    headers: {
      'Content-Type': 'text/html',
    },
    body: html_body
  }
end
