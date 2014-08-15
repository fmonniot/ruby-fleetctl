require 'fleetctl/fetcher'

module Fleet
  class Controller
    attr_writer :units
    attr_accessor :cluster

    def initialize
      @cluster = Fleet::Cluster.new(controller: self)
    end

    # returns an array of Fleet::Machine instances
    def machines
      cluster.machines
    end

    # returns an Fleet::ItemSet of Fleet::Unit instances
    def units
      return @units if @units
      machines

      @units = Fleet::ItemSet.new
      fetcher.fetch_units self
      @units
    end

    # refreshes local state to match the fleet cluster
    def sync
      build_fleet
      fetcher.fetch_units self
      true
    end

    # find a unitfile of a specific name
    def [](unit_name)
      units.detect { |u| u.name == unit_name }
    end

    # define actions on units
    [:start, :submit, :load].each do |method_name|
      # accepts one or more File objects, or an array of File objects
      define_method(method_name) do |*unit_file_or_files|
        unitfiles = unit_file_or_files.flatten
        out       = unitfile_operation(method_name, unitfiles)
        clear_units
        out
      end
    end

    def destroy(*unit_names)
      runner = Fleetctl::Command.run('destroy', unit_names)
      clear_units
      runner.exit_code == 0
    end

    private

    def fetcher
      Fleetctl.logger.info 'Call to Fetcher.fetch_units ' + self.inspect
      @fetcher ||= Fleetctl::Fetcher.new fleet_host
    end

    def build_fleet
      cluster.discover!
    end

    def fleet_host
      cluster.fleet_host
    end

    def clear_units
      @units = nil
    end

    def unitfile_operation(command, files)
      clear_units
      if Fleetctl.options.runner_class.to_s == 'Shell'
        runner = Fleetctl::Command.run(command.to_s, files.map(&:path))
      else
        runner = nil
        Fleetctl::RemoteTempfile.open(*files) do |*remote_filenames|
          runner = Fleetctl::Command.run(command.to_s, remote_filenames)
        end
      end
      runner.exit_code == 0
    end
  end
end
