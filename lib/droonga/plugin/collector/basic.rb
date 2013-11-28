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

require "droonga/collector_plugin"

module Droonga
  class BasicCollector < Droonga::CollectorPlugin
    repository.register("basic", self)

    UNLIMITED = -1

    command :collector_gather
    def collector_gather(result)
      output = body ? body[input_name] : input_name
      if output.is_a?(Hash)
        element = output["element"]
        if element
          result[element] = apply_output_range(result[element], output)
          result[element] = apply_output_format(result[element], output)
        end
        output = output["source"]
      end
      emit(result, output)
    end

    def apply_output_range(items, output)
      if items && items.is_a?(Array)
        offset = output["offset"] || 0
        unless offset.zero?
          items = items[offset..-1]
        end

        limit = output["limit"] || 0
        unless limit == UNLIMITED
          items = items[0...limit]
        end
      end
      items
    end

    def apply_output_format(items, output)
      format = output["format"]
      attributes = output["attributes"]
      if format == "complex" && attributes
        items.collect! do |item|
          complex_item = {}
          item.each_with_index do |value, index|
            label = attributes[index]
            complex_item[label] = value if label
          end
          complex_item
        end
      end
      items
    end

    command :collector_reduce
    def collector_reduce(request)
      return unless request
      body[input_name].each do |output, elements|
        value = request
        old_value = output_values[output]
        value = reduce(elements, old_value, request) if old_value
        emit(value, output)
      end
    end

    def reduce(elements, *values)
      result = {}
      elements.each do |key, deal|
        reduced_values = nil

        case deal["type"]
        when "sum"
          reduced_values = values[0][key] + values[1][key]
        when "sort"
          reduced_values = merge(values[0][key], values[1][key], deal["order"])
        end

        reduced_values = apply_output_range(reduced_values, "limit" => deal["limit"])

        result[key] = reduced_values
      end
      return result
    end

    def merge(x, y, order)
      index = 0
      y.each do |_y|
        loop do
          _x = x[index]
          break unless _x
          break if compare(_y, _x, order)
          index += 1
        end
        x.insert(index, _y)
        index += 1
      end
      return x
    end

    def compare(x, y, operators)
      for index in 0..x.size-1 do
        _x = x[index]
        _y = y[index]
        operator = operators[index]
        break unless operator
        return true if _x.__send__(operator, _y)
      end
      return false
    end
  end
end
