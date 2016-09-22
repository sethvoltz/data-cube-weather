#!/usr/bin/env ruby

require 'eventmachine'
require 'forecast_io'
require 'net/http'
require 'json'

ForecastIO.configure do |configuration|
  configuration.api_key = ENV['FORECAST_IO_KEY']
end

# The main juju
class WeatherCube
  def initialize
    puts 'Starting up...'
    show_weather
  end

  def start
    EventMachine.run do
      puts 'Main event loop'
      @weather_timer = EventMachine::PeriodicTimer.new(15 * 60) do
        show_weather
      end
    end
  end

  def stop
    @weather_timer.cancel
  end

  def show_weather
    colors = weather_to_colors(
      forecast.currently.icon,
      forecast.currently.apparentTemperature,
      Time.at(forecast.currently.time)
    )
    send_colors(colors)
  end

  def weather_to_colors(time, temperature, summary)
    # Turn current time, temperature and description into a set of 6 colors
    # Color order on cube
    # 1 \   / 3
    #  2 \ / 4
    #   6 |
    #   5 |
    [base_color(summary)] * 6
  end

  def base_color(summary)
    # Summary can be one of:
    #   clear-day, clear-night, rain, snow, sleet, wind, fog,
    #   cloudy, partly-cloudy-day, or partly-cloudy-night
    { 'clear-day' => '3ec3f5', 'clear-night' => '125e9c',
      'rain' => '246dea',
      'snow' => '88b5e3',
      'sleet' => '65b9c2',
      'wind' => 'aac399',
      'fog' => '8ac5ae', 'cloudy' => '8ac5ae',
      'partly-cloudy-day' => '9cc0c2', 'partly-cloudy-night' => '7996a7'
    }[summary] || 'cccccc'
  end

  def send_colors(colors)
    # Send colors to edged
    puts 'colors received', colors
  end

  def forecast
    unless (Time.now - last_forecast) < (10 * 60)
      puts 'Fetching forecast...'
      @forecast = ForecastIO.forecast(*coordinates)
    end

    @forecast
  end

  def last_forecast
    @forecast ? Time.at(@forecast.currently.time) : Time.at(0)
  end

  def coordinates?
    @location && @location['latitude'] && @location['longitude']
  end

  def coordinates
    unless coordinates?
      puts 'Fetching coordinates...'
      @location = JSON.parse(Net::HTTP.get(URI('https://freegeoip.net/json/')))
    end
    [@location['latitude'], @location['longitude']]
  end
end

WeatherCube.new.start
