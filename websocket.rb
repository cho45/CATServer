#!/usr/bin/env ruby

require "em-websocket"
require "json"
require "./cat.rb"

@cat = CAT::FT450D.new({ :port => '/dev/tty.usbserial-FTB3L9UG' })

EM::run do
	@channel = EM::Channel.new
	@status  = nil

	EM::WebSocket.start(:host => "0.0.0.0", :port => 51234) do |ws|
		ws.onopen do
			ws.send(JSON.generate(@status)) if @status

			sid = @channel.subscribe do |mes|
				ws.send(mes)
			end

			ws.onclose do
				@channel.unsubscribe(sid)
			end
		end

		ws.onmessage do |msg|
			begin
				cmd = JSON.parse(msg)
				case cmd["command"]
				when "power"
					@cat.power = cmd["value"]
				when "frequency"
					@cat.frequency = cmd["value"]
				when "mode"
					@cat.mode = cmd["value"]
				end
			rescue Timeout::Error
				puts "timeout"
				ws.send(JSON.generate({ "error" => "timeout" }))
			end
		end
	end

	EM::defer do
		begin
			@cat.status do |status|
				@status = status
				@channel.push JSON.generate(@status)
			end
		rescue Timeout::Error
			warn "timeout"
			sleep 1
			retry
		end
	end
end

