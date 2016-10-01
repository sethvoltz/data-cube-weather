#!/usr/bin/env ruby

require 'eventmachine'
require 'forecast_io'
require 'net/http'
require 'socket'
require 'json'
require 'color'

$stdout.sync = true # All logging flush immediately

CUBE_HOST = 'localhost'.freeze
CUBE_PORT = 8300

PositiveInfinity = +1.0 / 0.0
NegativeInfinity = -1.0 / 0.0

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
      Time.at(forecast.currently.time),
      forecast.currently.apparentTemperature,
      forecast.currently.icon
    )
    send_colors(colors)
  end

  def weather_to_colors(time, temperature, summary)
    # Turn current time, temperature and description into a set of 6 colors
    # Color order on cube
    # 0 \   / 2
    #  1 \ / 3
    #   5 |
    #   4 |
    colors = [base_color(summary)] * 6

    tip = tip_color(temperature)
    if tip
      colors[1] = hex_blend(colors[1], tip, 95)
      colors[3] = hex_blend(colors[3], tip, 95)
      colors[5] = hex_blend(colors[5], tip, 95)
    end
    colors
  end

  def base_color(summary)
    # Summary can be one of:
    #   clear-day, clear-night, rain, snow, sleet, wind, fog,
    #   cloudy, partly-cloudy-day, or partly-cloudy-night
    { 'clear-day' => '3ec3f5', 'clear-night' => '0d3779',
      'rain' => '246dea',
      'snow' => '88b5e3',
      'sleet' => '65b9c2',
      'wind' => 'aac399',
      'fog' => '8ac5ae', 'cloudy' => '8ac5ae',
      'partly-cloudy-day' => '9cc0c2', 'partly-cloudy-night' => '7996a7'
    }[summary] || 'cccccc'
  end

  def tip_color(temperature)
    case temperature
    when NegativeInfinity..32 then '1200da'  # cold blue
    when 60..75 then '27d06c'                # pleasant green
    when 75..85 then 'e1ad1a'                # yellowy hot
    when 85..95 then 'db5915'                # orangy hot
    when 95..PositiveInfinity then 'd52a23'  # hot red
    end
  end

  def hex_blend(mask, base, opacity)
    Color::RGB.by_hex(base).mix_with(Color::RGB.by_hex(mask), opacity).hex
  end

  def send_colors(colors)
    # Send colors to edged
    puts "colors received: #{colors.to_json}"
    socket = TCPSocket.open(CUBE_HOST, CUBE_PORT)
    socket.print({
      'command' => 'setColors',
      'colors' => colors,
      'mode' => 'ambient'
    }.to_json + "\r\n")
    if JSON.parse(socket.readline)['success'] == false
      # TODO: Handler errors
    end
    socket.print("\r\n")
    socket.close
  end

  def forecast
    unless (Time.now - last_forecast) < (10 * 60)
      puts 'Fetching forecast...'
      @forecast = ForecastIO.forecast(*coordinates)
      result = [
        @forecast.currently.icon,
        @forecast.currently.apparentTemperature
      ].join(', ')
      puts " --> Forecast: #{result}"
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
      @location = load_location_from_env || load_location_from_service
      result = [@location['latitude'], @location['longitude']].join(', ')
      puts " --> Coordinates: #{result}"
    end
    [@location['latitude'], @location['longitude']]
  end

  def load_location_from_service
    puts 'Fetching coordinates...'
    JSON.parse(Net::HTTP.get(URI('https://freegeoip.net/json/')))
  end

  def load_location_from_env
    return unless ENV['LATITUDE'] && ENV['LONGITUDE']
    puts 'Loading coordinates from environment...'
    {
      'latitude' => ENV['LATITUDE'].to_f,
      'longitude' => ENV['LONGITUDE'].to_f
    }
  end
end

WeatherCube.new.start
