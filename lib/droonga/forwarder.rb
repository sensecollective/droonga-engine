# -*- coding: utf-8 -*-
#
# Copyright (C) 2013 Droonga Project
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License version 2.1 as published by the Free Software Foundation.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require "droonga/loggable"
require "droonga/path"
require "droonga/event_loop"
require "droonga/fluent_message_sender"

module Droonga
  class Forwarder
    include Loggable

    def initialize(loop)
      @loop = loop
      @senders = {}
    end

    def start
      logger.trace("start: start")
      logger.trace("start: done")
    end

    def shutdown
      logger.trace("shutdown: start")
      @senders.each_value do |sender|
        sender.shutdown
      end
      logger.trace("shutdown: done")
    end

    def forward(message, destination)
      logger.trace("forward: start")
      command = destination["type"]
      receiver = destination["to"]
      arguments = destination["arguments"]
      reserve = destination["reserve"]
      output(receiver, message, command, arguments, :reserve => reserve)
      logger.trace("forward: done")
    end

    def resume
      return unless Path.buffer.exist?
      Pathname.glob("#{Path.buffer}/*") do |path|
        next unless path.directory?
        next if Pathname.glob("#{path.to_s}/*").empty?

        destination = path.basename.to_s
        next if @senders.key?(destination)

        components = destination.split(":")
        port = components.pop.to_i
        next if port.zero?
        host = components.join(":")

        sender = create_sender(host, port)
        sender.resume
        @senders[destination] = sender
      end
    end

    private
    def output(receiver, message, command, arguments, options={})
      logger.trace("output: start")
      if not receiver.is_a?(String) or not command.is_a?(String)
        logger.trace("output: abort: invalid argument",
                     :receiver => receiver,
                     :command  => command)
        return
      end
      unless receiver =~ /\A(.*):(\d+)\/(.*?)(\?.+)?\z/
        raise "format: hostname:port/tag(?params)"
      end
      host = $1
      port = $2
      tag  = $3
      params = $4
      sender = find_sender(host, port, params)
      unless sender
        logger.trace("output: abort: no sender",
                     :host   => host,
                     :port   => port,
                     :params => params)
        return
      end
      override_message = {
        "type" => command,
      }
      override_message["arguments"] = arguments if arguments
      message = message.merge(override_message)
      output_tag = "#{tag}.message"
      log_info = "<#{receiver}>:<#{output_tag}>"
      logger.trace("output: post: start: #{log_info}")
      if options[:reserve]
        sender.reserve_send(output_tag, message)
      else
        sender.send(output_tag, message)
      end
      logger.trace("output: post: done: #{log_info}")
      logger.trace("output: done")
    end

    def find_sender(host, port, params)
      connection_id = extract_connection_id(params)
      destination = "#{host}:#{port}"
      destination << "?#{connection_id}" if connection_id

      @senders[destination] ||= create_sender(host, port)
    end

    def extract_connection_id(params)
      return nil unless params

      if /[\?&;]connection_id=([^&;]+)/ =~ params
        $1
      else
        nil
      end
    end

    def create_sender(host, port)
      sender = FluentMessageSender.new(@loop, host, port)
      sender.start
      sender
    end

    def log_tag
      "[#{Process.ppid}][#{Process.pid}] forwarder"
    end
  end
end
