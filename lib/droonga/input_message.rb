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

module Droonga
  class InputMessage
    def initialize(envelope)
      @envelope = envelope
    end

    def adapted_envelope
      # TODO: We can create adapted envelope non-destructively.
      # If it is not performance issue, it is better that we don't
      # change envelope destructively. Consider about it later.
      @envelope
    end

    def add_route(route)
      @envelope["via"].push(route)
    end

    def body
      @envelope["body"]
    end

    def body=(body)
      @envelope["body"] = body
    end

    def command
      @envelope["type"]
    end

    def command=(command)
      @envelope["type"] = command
    end
  end
end
