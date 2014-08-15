require 'fleetctl/sshable'

module Fleet
  class Machine
    include Fleetctl::SSHable

    attr_reader :cluster, :id, :ip, :metadata
    alias_method :read_attribute_for_serialization, :send

    def initialize(params)
      @cluster = params[:cluster]
      @id = params[:id]
      @ip = params[:ip]
      @metadata = params[:metadata]
    end

    def units
      @cluster.controller.units.select { |unit| unit.machine.id == id }
    end

    def ==(other_machine)
      id == other_machine.id && ip == other_machine.ip
    end

    alias_method :eql?, :==
  end
end
