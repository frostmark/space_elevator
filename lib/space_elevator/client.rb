require 'json'

module SpaceElevator
  class Client
    attr_accessor :client, :connected, :connection_handler,
                  :channel_handlers, :disconnect_handler, :urls

    def initialize(url, &disconnect_handler)
      @url = url
      @disconnect_handler = disconnect_handler
    end

    def connect(&block)
      connection_handler = block
      channel_handlers = {}
      client = EventMachine::WebSocketClient.connect(url)
      client.callback do
        puts "Connected WebSocket to #{url}."
        connected = true
      end
      client.stream do |raw|
        message = parse_message(raw.to_s)
        if message['identifier']
          channel_handlers[message['identifier'].to_json].call(message)
        else
          connection_handler.call(message)
        end
      end
      client.disconnect do
        connected = false
        disconnect_handler.call
      end
     end

    def subscribe(identifier, &block)
      push(create_subscribe_message(identifier))
      channel_handlers[identifier.to_json] = block
    end

    def push(msg)
      client.send_msg(msg)
    end

    def publish(identifier, data)
      msg = create_publish_message(identifier, data)
      # puts "PUSHING: #{msg}"
      push(msg)
    end

    def create_publish_message(identifier, data)
      message = {
        command: 'message',
        identifier: identifier
      }
      message[:data] = data.to_json if data
      message[:identifier] = message[:identifier].to_json
      message.to_json
    end

    def create_subscribe_message(identifier)
      message = {
        command: 'subscribe',
        identifier: identifier.to_json
      }
      # message[:identifier].merge!(data) if data
      # message[:data] = data.to_json if data
      # message[:identifier] = message[:identifier].to_json
      # puts message
      message.to_json
    end

    def parse_message(message)
      result = JSON.parse(message)
      result['identifier'] = JSON.parse(result['identifier']) if result['identifier']
      result['data'] = JSON.parse(result['data']) if result['data']
      result
    end
  end
end
