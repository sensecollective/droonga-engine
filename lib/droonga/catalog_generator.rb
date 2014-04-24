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

require "time"

module Droonga
  class CatalogGenerator
    def initialize
      @version = 2
      @effective_date = Time.now
      @datasets = {}
    end

    def add_dataset(name, options)
      @datasets[name] = Dataset.new(name, options)
    end

    def generate
      {
        "version"       => @version,
        "effectiveDate" => @effective_date.iso8601,
        "datasets"      => catalog_datasets,
      }
    end

    private
    def catalog_datasets
      catalog_datasets = {}
      @datasets.each do |name, dataset|
        catalog_datasets[name] = dataset.to_catalog
      end
      catalog_datasets
    end

    class Dataset
      def initialize(name, options)
        @name = name
        @options = options
      end

      def n_workers
        @options[:n_workers] || 4
      end

      def plugins
        @options[:plugins] || ["groonga", "search", "crud"]
      end

      def schema
        @options[:schema] || {}
      end

      def fact
        @options[:fact]
      end

      def replicas
        return @options[:replicas] if @options[:replicas]
        @generated_replicas ||= Replicas.new(@options).to_json
      end

      def to_catalog
        catalog = {
          "nWorkers" => n_workers,
          "plugins"  => plugins,
          "schema"   => schema,
          "replicas" => replicas,
        }
        catalog["fact"] = fact if fact
        catalog
      end

      private
    end

    class Replicas
      def initialize(parameters={})
        @host       = parameters[:host]       || "127.0.0.1"
        @port       = parameters[:port]       || 10031
        @tag        = parameters[:tag]        || "droonga"
        @n_replicas = parameters[:n_replicas] || 2
        @n_slices   = parameters[:n_slices]   || 1

        @n_volumes = 0
      end

      def to_json
        @json ||= generate_json
      end

      private
      def generate_json
        replicas = []
        @n_replicas.times do |index|
          replicas << generate_replica
        end
        replicas
      end

      def generate_replica
        slices = []
        @n_slices.times do |index|
          slices << generate_slice
        end
        {
          "dimension" => "_key",
          "slicer" => "hash",
          "slices" => slices,
        }
      end

      def generate_slice
        name = sprintf('%03d', @n_volumes)
        @n_volumes += 1
        {
          "weight" => weight,
          "volume" => {
            "address" => "#{@host}:#{@port}/#{@tag}.#{name}",
          },
        }
      end

      def weight
        @weight ||= 100 / @n_slices
      end
    end
  end
end
