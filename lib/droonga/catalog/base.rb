# Copyright (C) 2013-2014 Droonga Project
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

require "digest/sha1"
require "zlib"
require "time"
require "droonga/error_messages"
require "droonga/catalog/errors"

module Droonga
  module Catalog
    class Base
      attr_reader :path, :base_path
      def initialize(data, path)
        @data = data
        @path = path
        @base_path = File.dirname(path)
      end

      def have_dataset?(name)
        datasets.key?(name)
      end

      def dataset(name)
        datasets[name]
      end
    end
  end
end
