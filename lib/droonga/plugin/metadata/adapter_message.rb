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
      class AdapterMessage
        def initialize(adapter_class)
          @adapter_class = adapter_class
        end

        def input_pattern
          configuration[:input_pattern]
        end

        def input_pattern=(pattern)
          configuration[:input_pattern] = pattern
        end

        def output_pattern
          configuration[:output_pattern]
        end

        def output_pattern=(pattern)
          configuration[:output_pattern] = pattern
        end

        private
        def configuration
          @adapter_class.options[:message] ||= {}
        end
      end
    end
  end
end