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

  def weather_to_colors(time, temperature, description)
    # Turn current time, temperature and description into a set of 6 colors
    %w( ff0000 ff0000 00ff00 00ff00 0000ff 0000ff )
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
