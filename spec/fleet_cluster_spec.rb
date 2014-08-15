describe Fleet::Cluster do

  before :all do
    Fleetctl.config logger: Support::empty_logger
  end

  let(:controller) { double 'controller' }
  subject { Fleet::Cluster.new controller: controller }

  it 'should be correctly initialized' do
    expect(subject.controller).to eq(controller)
    expect(subject.fleet_hosts).to be_empty
    expect(subject.fleet_host).to be_nil
  end

  context 'when we have three machines' do

    let(:ips) { [] }
    let(:machines) { [] }
    before :each do
      3.times do
        ip      = Support::random_ipv4
        machine = Fleet::Machine.new ip: ip

        subject.add_or_find machine
        ips << ip
        machines << machine
      end
    end

    it 'should return an array of ips' do
      expect(subject.fleet_hosts).to eq(ips)
    end

    it 'should return an ip from the pool' do
      expect(ips).to include(subject.fleet_host)
    end

    it 'should return all machines' do
      expect(subject.machines).to eq(machines)
    end

    it 'should not discover new machines' do
      expect(subject).to_not receive(:discover!)

      subject.machines
    end
  end

  context "when we don't have any machine" do
    it 'should load the cluster machines' do
      expect(subject).to receive(:discover!)

      subject.machines
    end
  end

  describe '#discover!' do

    let(:fleet_host) { Support::random_ipv4 }
    let(:logger) { Support::empty_logger }

    before :each do
      Fleetctl.config fleet_host: fleet_host, logger: logger
    end

    it 'should rebuild the cluster with the default fleet_host' do
      expect(subject).to receive(:build_from).
                             with([fleet_host]).
                             and_return(fleet_host)

      expect(logger).to receive(:info).with(Regexp.new fleet_host)

      subject.discover!
    end

    it 'should rebuild the cluster with a previously discovered host' do
      # Add previous machines
      ips = [fleet_host]
      3.times do
        ip = Support::random_ipv4

        subject.add_or_find Fleet::Machine.new ip: ip
        ips << ip
      end

      # Specification
      expect(subject).to receive(:build_from).
                             with(ips).
                             and_return(fleet_host)

      expect(logger).to receive(:info).with(Regexp.new fleet_host)

      subject.discover!
    end

    it 'should rebuild the cluster with the discovery URL' do
      Fleetctl.config logger: logger, discovery_url: 'url'
      allow(Fleet::Discovery).to receive(:hosts).and_return([])

      expect(subject).to receive(:build_from).with([nil])
      expect(subject).to receive(:build_from).
                             with(Fleet::Discovery.hosts).
                             and_return(fleet_host)

      expect(logger).to receive(:info).with(Regexp.new fleet_host)

      subject.discover!
    end

    it 'should log a failure' do
      allow(subject).to receive(:build_from)
      expect(logger).to receive(:info).with(/Unable to recover/)

      subject.discover!
    end
  end

  describe '#build_from' do
    let(:ip_addrs) { Array.new(3) { Support::random_ipv4 } }
    let(:fetcher) { double('fetcher', fetch_machines: true) }
    let(:invalid_fetcher) { double('invalid fetcher', fetch_machines: false) }

    it 'should stop fetching machine when the first IP is valid' do
      expect(Fleetctl::Fetcher).to receive(:new).once
                                   .with(ip_addrs[0])
                                   .and_return(fetcher)
      expect(Fleetctl::Fetcher).to_not receive(:new).with(ip_addrs[1])

      expect(subject.build_from ip_addrs).to eq(ip_addrs[0])
    end

    it 'should stop fetching machine when the second IP is valid' do
      expect(Fleetctl::Fetcher).to receive(:new).once
                                   .with(ip_addrs[0])
                                   .and_return(invalid_fetcher)
      expect(Fleetctl::Fetcher).to receive(:new).once
                                   .with(ip_addrs[1])
                                   .and_return(fetcher)
      expect(Fleetctl::Fetcher).to_not receive(:new).with(ip_addrs[2])

      expect(subject.build_from ip_addrs).to eq(ip_addrs[1])
    end

    it 'should raise and log error if error' do
      allow(fetcher).to receive(:fetch_machines).and_raise(RuntimeError)
      allow(Fleetctl::Fetcher).to receive(:new).and_return(fetcher)

      expect(Fleetctl.logger).to receive(:error).at_least(3).times
      expect(subject.build_from ip_addrs).to be_nil
    end
  end
end