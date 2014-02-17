# Copyright (C) 2014 Droonga Project
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
  module Plugin
    module Metadata
      class PlannerMessage
        def initialize(plugin_class)
          @plugin_class = plugin_class
        end

        def pattern
          configuration[:pattern] || fallback_pattern
        end

        def pattern=(pattern)
          configuration[:pattern] = pattern
        end

        def type
          configuration[:type]
        end

        def type=(type)
          configuration[:type] = type
        end

        private
        def configuration
          @plugin_class.options[:message] ||= {}
        end

        def fallback_pattern
          return nil if type.nil?
          ["type", :equal, type]
        end
      end
    end
  end
end