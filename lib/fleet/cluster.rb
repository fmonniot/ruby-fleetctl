module Fleet
  class Cluster < Fleet::ItemSet
    attr_accessor :controller
    alias_method :read_attribute_for_serialization, :send

    def initialize(*args, controller: nil)
      @controller = controller
      super(*args)
    end

    def fleet_hosts
      map(&:ip)
    end

    def fleet_host
      fleet_hosts.sample
    end

    def machines
      discover! if empty?
      to_a
    end

    # attempts to rebuild the cluster by the specified fleet host, then hosts that it
    # has built previously, and finally by using the discovery url
    def discover!
      known_hosts = [Fleetctl.options.fleet_host] | fleet_hosts.to_a
      clear
      success_host = build_from(known_hosts) || build_from(Fleet::Discovery.hosts)
      if success_host
        Fleetctl.logger.info 'Successfully recovered from host: ' + success_host.inspect
      else
        Fleetctl.logger.info 'Unable to recover!'
      end
    end

    # attempts to rebuild the cluster from any of the hosts passed as arguments
    # returns the first ip that worked, else nil
    def build_from(*ip_addrs)
      ip_addrs = [*ip_addrs].flatten.compact
      begin
        Fleetctl.logger.info 'building from hosts: ' + ip_addrs.inspect

        built_from = ip_addrs.detect do |ip_addr|
          Fleetctl::Fetcher.new(ip_addr).fetch_machines self
        end

        Fleetctl.logger.info 'built successfully from host: ' + built_from.inspect if built_from

        built_from
      rescue => e
        Fleetctl.logger.error 'ERROR building from hosts: ' + ip_addrs.inspect
        Fleetctl.logger.error e.message
        Fleetctl.logger.error e.backtrace.join("\n")
        nil
      end
    end
  end
end
