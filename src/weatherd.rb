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
    fetch_and_show_weather
  end

  def start
    EventMachine.run do
      @weather_timer = EventMachine::PeriodicTimer.new(15 * 60) do
        fetch_and_show_weather
      end
    end
  end

  def stop
    @weather_timer.cancel
  end

  def fetch_coordinates
    coordinates = JSON.parse(Net::HTTP.get(URI('https://freegeoip.net/json/')))
    @longitude = coordinates['longitude']
    @latitude  = coordinates['latitude']
  end

  def fetch_and_show_weather
    fetch_coordinates unless @latitude && @longitude
    @forecast = ForecastIO.forecast(@latitude, @longitude)
    puts "The weather is #{@forecast.currently.icon}, #{@forecast.currently.apparentTemperature}"
  end
end

WeatherCube.new.start
