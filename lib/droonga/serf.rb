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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

require "English"

require "json"
require "coolio"
require "open3"

require "droonga/path"
require "droonga/loggable"
require "droonga/catalog_loader"
require "droonga/node_status"
require "droonga/serf_downloader"
require "droonga/line_buffer"

module Droonga
  class Serf
    ROLE = {
      :default => {
        :port => 7946,
      },
      :source => {
        :port => 7947,
      },
      :destination => {
        :port => 7948,
      },
    }

    class << self
      def path
        Droonga::Path.base + "serf"
      end

      def send_query(name, query, payload)
        new(nil, name).send_query(query, payload)
      end

      def live_nodes(name)
        new(nil, name).live_nodes
      end
    end

    include Loggable

    def initialize(loop, name)
      # TODO: Don't allow nil for loop. It reduces nil checks and
      # simplifies source code.
      @loop = loop
      @name = name
      @agent = nil
    end

    def start
      logger.trace("start: start")
      ensure_serf
      ENV["SERF"] = @serf
      ENV["SERF_RPC_ADDRESS"] = rpc_address
      retry_joins = []
      detect_other_hosts.each do |other_host|
        retry_joins.push("-retry-join", other_host)
      end
      @agent = run("agent",
                   "-node", @name,
                   "-bind", "#{extract_host(@name)}:#{port}",
                   "-event-handler", "droonga-engine-serf-event-handler",
                   "-log-level", log_level,
                   *retry_joins)
      logger.trace("start: done")
    end

    def running?
      @agent and @agent.running?
    end

    def stop
      logger.trace("stop: start")
      run("leave").stop
      @agent.stop
      @agent = nil
      logger.trace("stop: done")
    end

    def send_query(query, payload)
      ensure_serf
      options = ["-format", "json"] + additional_options_from_payload(payload)
      options += [query, JSON.generate(payload)]
      result = run_once("query", *options)
      if payload["node"]
        responses = result[:result]["Responses"]
        response = responses[payload["node"]]
        if response.is_a?(String)
          begin
            result[:response] = JSON.parse(response)
          rescue JSON::ParserError
            result[:response] = response
          end
        else
          result[:response] = response
        end
      end
      result
    end

    def live_nodes
      ensure_serf
      nodes = {}
      result= run_once("members", "-format", "json")
      members = result[:result]
      members["members"].each do |member|
        if member["status"] == "alive"
          nodes[member["name"]] = {
            "serfAddress" => member["addr"],
            "tags"        => member["tags"],
          }
        end
      end
      nodes
    end

    private
    def ensure_serf
      @serf = find_system_serf
      return if @serf

      serf_path = self.class.path
      @serf = serf_path.to_s
      return if serf_path.executable?
      downloader = SerfDownloader.new(serf_path)
      downloader.download
    end

    def find_system_serf
      paths = (ENV["PATH"] || "").split(File::PATH_SEPARATOR)
      paths.each do |path|
        serf = File.join(path, "serf")
        return serf if File.executable?(serf)
      end
      nil
    end

    def run(command, *options)
      process = SerfProcess.new(@loop, @serf, command,
                                "-rpc-addr", rpc_address,
                                *options)
      process.start
      process
    end

    def run_once(command, *options)
      process = SerfProcess.new(@loop, @serf, command,
                                "-rpc-addr", rpc_address,
                                *options)
      process.run_once
    end

    def additional_options_from_payload(payload)
      options = []
      if payload.is_a?(Hash) and payload.include?("node")
        options += ["-node", payload["node"]]
      end
      options
    end

    def extract_host(node_name)
      node_name.split(":").first
    end

    def log_level
      level = Logger::Level.default
      case level
      when "trace", "debug", "info", "warn"
        level
      when "error", "fatal"
        "err"
      else
        level # Or error?
      end
    end

    def rpc_address
      "#{extract_host(@name)}:7373"
    end

    def node_status
      @node_status ||= NodeStatus.new
    end

    def role
      if node_status.have?(:role)
        role = node_status.get(:role).to_sym
        if self.class::ROLE.key?(role)
          return role
        end
      end
      :default
    end

    def port
      self.class::ROLE[role][:port]
    end

    def detect_other_hosts
      loader = CatalogLoader.new(Path.catalog.to_s)
      catalog = loader.load
      other_nodes = catalog.all_nodes.reject do |node|
        node == @name
      end
      other_nodes.collect do |node|
        extract_host(node)
      end
    end

    def log_tag
      "serf"
    end

    class SerfProcess
      include Loggable

      def initialize(loop, serf, command, *options)
        @loop = loop
        @serf = serf
        @command = command
        @options = options
        @pid = nil
      end

      def start
        capture_output do |output_write, error_write|
          env = {}
          spawn_options = {
            :out => output_write,
            :err => error_write,
          }
          @pid = spawn(env, @serf, @command, *@options, spawn_options)
        end
      end

      def stop
        return if @pid.nil?
        Process.waitpid(@pid)
        @output_io.close
        @error_io.close
        @pid = nil
      end

      def running?
        not @pid.nil?
      end

      def run_once
        stdout, stderror, status = Open3.capture3(@serf, @command, *@options, :pgroup => true)
        {
          :result => JSON.parse(stdout),
          :error  => stderror,
          :status => status,
        }
      end

      private
      def capture_output
        result = nil
        output_read, output_write = IO.pipe
        error_read, error_write = IO.pipe

        begin
          result = yield(output_write, error_write)
        rescue
          output_read.close  unless output_read.closed?
          output_write.close unless output_write.closed?
          error_read.close   unless error_read.closed?
          error_write.close  unless error_write.closed?
          raise
        end

        output_line_buffer = LineBuffer.new
        on_read_output = lambda do |data|
          on_standard_output(output_line_buffer, data)
        end
        @output_io = Coolio::IO.new(output_read)
        @output_io.on_read do |data|
          on_read_output.call(data)
        end
        # TODO: Don't allow nil for loop. It reduces nil checks and
        # simplifies source code.
        @loop.attach(@output_io) if @loop

        error_line_buffer = LineBuffer.new
        on_read_error = lambda do |data|
          on_error_output(error_line_buffer, data)
        end
        @error_io = Coolio::IO.new(error_read)
        @error_io.on_read do |data|
          on_read_error.call(data)
        end
        # TODO: Don't allow nil for loop. It reduces nil checks and
        # simplifies source code.
        @loop.attach(@error_io) if @loop

        result
      end

      def on_standard_output(line_buffer, data)
        line_buffer.feed(data) do |line|
          line = line.chomp
          case line
          when /\A==> /
            content = $POSTMATCH
            logger.info(content)
          when /\A    /
            content = $POSTMATCH
            case content
            when /\A(\d{4})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2}):(\d{2}) \[(\w+)\] /
              year, month, day = $1, $2, $3
              hour, minute, second = $4, $5, $6
              level = $7
              content = $POSTMATCH
              level = normalize_level(level)
              logger.send(level, content)
            else
              logger.info(content)
            end
          else
            logger.info(line)
          end
        end
      end

      def normalize_level(level)
        level = level.downcase
        case level
        when "err"
          "error"
        else
          level
        end
      end

      def on_error_output(line_buffer, data)
        line_buffer.feed(data) do |line|
          line = line.chomp
          logger.error(line.gsub(/\A==> /, ""))
        end
      end

      def log_tag
        tag = "serf"
        tag << "[#{@pid}]" if @pid
        tag
      end
    end
  end
end
