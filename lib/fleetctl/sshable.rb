module Fleetctl

  # A module/class which include this module must have a ip accessor which will
  # return the ip address of the distant host
  module SSHable

    # run the command (string, array of command + args, whatever)
    # and return stdout
    def ssh(*command, port: 22)
      runner = Fleetctl::Runner::SSH.new([*command].flatten.compact.join(' '))
      runner.run(host: ip, ssh_options: { port: port })
      runner.output
    end
  end
end