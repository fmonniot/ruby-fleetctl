module Fleetctl
  class Fetcher

    def initialize(fleet_host)
      @fleet_host = fleet_host
    end

    def fetch(*commands)
      Fleetctl::Command.new(*commands) do |runner|
        runner.run(host: @fleet_host)

        yield(runner.output) if block_given?

        runner.exit_code == 0
      end
    end

    def fetch_machines(cluster)
      Fleetctl.logger.info 'Fetching machines from host: '+ @fleet_host.inspect
      fetch 'list-machines', '-l' do |output|
        parse_machines(output, cluster)
      end
    end

    def fetch_units(controller)
      Fleetctl.logger.info 'Fetching units from host: '+ @fleet_host.inspect
      fetch 'list-units', '-l' do |output|
        parse_units(output, controller)
      end
    end

    def parse_machines(raw_table, cluster)
      machine_hashes = Fleetctl::TableParser.parse(raw_table)
      machine_hashes.map do |machine_attrs|
        machine_attrs[:id]      = machine_attrs.delete(:machine)
        machine_attrs[:cluster] = cluster
        cluster.add_or_find(Fleet::Machine.new(machine_attrs))
      end
    end

    def parse_units(raw_table, controller)
      unit_hashes = Fleetctl::TableParser.parse(raw_table)
      unit_hashes.each do |unit_attrs|
        if unit_attrs[:machine]
          machine_id, machine_ip = unit_attrs[:machine].split('/')
          unit_attrs[:machine]   = controller.cluster.add_or_find(
              Fleet::Machine.new(id: machine_id, ip: machine_ip)
          )
        end
        unit_attrs[:name]       = unit_attrs.delete(:unit)
        unit_attrs[:controller] = controller

        controller.units.add_or_find(Fleet::Unit.new(unit_attrs))
      end
    end

  end
end
