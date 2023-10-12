require 'compass_point'
require 'json'

class CurrentWeatherPresenter

  attr_reader :data

  def initialize(data)
    @data = data
  end

  def to_json
    {
      city: data.name,
      temperature: data.main.temp.round,
      weatherCondition: {
        type: data.weather.dig(0, 'main'),
        pressure: data.main.pressure,
        humidity: data.main.humidity
      },
      wind: {
        speed: data.wind.speed,
        direction: cardinal_direction_degrees(data.wind.deg)
      }
    }.to_json
  end

  private

  def cardinal_direction_degrees(s)
    CompassPoint.compass_quadrant_bearing(s).gsub!(/[^A-Za-z]+/, '').upcase
  end

end
