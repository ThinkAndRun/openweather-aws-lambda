require 'lib/get_current_weather_service'

def lambda_handler(event:, context:)
  city = event.dig('queryStringParameters', 'city')
  result = GetCurrentWeatherService.(city: city)

  {
    statusCode: result.success? ? 200 : 400,
    headers: { 'Content-Type': 'application/json' },
    body: result.success? ? result[:current_weather_json] : { error_message: result[:error_message] }.to_json
  }
end
