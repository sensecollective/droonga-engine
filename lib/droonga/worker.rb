# -*- coding: utf-8 -*-
#
# Copyright (C) 2013 droonga project
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

require 'groonga'
require "droonga/handler_plugin"

module Droonga
  class Worker
    def initialize(database, queue_name)
      @context = Groonga::Context.new
      @database = @context.open_database(database)
      @queue_name = queue_name
      @handlers = []
    end

    def add_handler(name)
      plugin = HandlerPlugin.new(name)
      @handlers << plugin.instantiate(@context)
    end

    def shutdown
      @handlers.each do |handler|
        handler.shutdown
      end
      @database.close
      @context.close
      @database = @context = nil
    end

    def process_message(envelope)
      command = envelope["type"]
      handler = find_handler(command)
      handler.handle(command, envelope["body"])
    end

    private
    def find_handler(command)
      @handlers.find do |handler|
        handler.handlable?(command)
      end
    end
  end
end
