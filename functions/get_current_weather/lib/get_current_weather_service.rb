require 'json'
require 'redis'
require 'aws-sdk-secretsmanager'
require "trailblazer/operation"
require 'open-weather-ruby-client'
require 'lib/current_weather_presenter'

class GetCurrentWeatherService < Trailblazer::Operation

  step :validate_city!
  step :getset_current_weather!

  def validate_city!(ctx, city:, **)
    ctx[:error_message] = case
                          when city == '' || city.nil?
                            'City is blank'
                          when !city.is_a?(String)
                            'City is not a string'
                          when city.match(/\d/)
                            'City should not contain digits'
                          when city.length < 3
                            'City is too short'
                          end

    ctx[:error_message].nil?
  end

  def getset_current_weather!(ctx, city:, **)
    redis = Redis.new(host: ENV['REDIS_ENDPOINT'], port: ENV['REDIS_PORT'])
    key = "current_weather_json_#{city}"

    current_weather_json = redis.get(key)
    unless current_weather_json
      current_weather_json = get_current_weather_json(city)
      redis.setex(key, 60, current_weather_json)
    end
    ctx[:current_weather_json] = current_weather_json

  rescue => e
    ctx[:error_message] = e.message
    false
  end

  private

  def open_weather_api_key
    secret_name = ENV['SECRET_NAME']
    client = Aws::SecretsManager::Client.new(region: ENV['AWS_REGION'])
    secret_value = client.get_secret_value(secret_id: secret_name)

    JSON.parse(secret_value.secret_string)['open_weather_api_key']
  end

  def get_current_weather_json(city)
    client = OpenWeather::Client.new(api_key: open_weather_api_key)
    data = client.current_weather(city: city, units: :metric, lang: :en)

    CurrentWeatherPresenter.new(data).to_json
  end

end
