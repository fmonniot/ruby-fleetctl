describe Fleetctl::Fetcher.new('8.8.8.8') do
  let(:host) { '8.8.8.8' }
  let(:runner) { double('runner').as_null_object }

  describe '#fetch' do

    before :each do
      allow(Fleetctl::Command).to receive(:new)
                                  .with('list-machines', '-l')
                                  .and_yield(runner)
    end

    it 'should execute the command on the correct host' do
      expect(runner).to receive(:run).with(hash_including(host: host)).once

      subject.fetch 'list-machines', '-l'
    end

    it 'should yield the result of the command' do
      allow(runner).to receive(:output).and_return('output')

      expect do |blk|
        subject.fetch 'list-machines', '-l', &blk
      end.to yield_with_args('output')
    end

    it 'should return true if the command was successful' do
      allow(runner).to receive(:exit_code).and_return(0)

      expect(subject.fetch 'list-machines', '-l').to be true
    end

    it 'should return false if the command was unsuccessful' do
      allow(runner).to receive(:exit_code).and_return(42)

      expect(subject.fetch 'list-machines', '-l').to be false
    end
  end

  describe '#fetch_machines' do
    let(:cluster) { double('cluster').as_null_object }

    before :each do
      allow(subject).to receive(:fetch)
                        .with('list-machines', '-l')
                        .and_yield('output')
      Fleetctl.config logger: Support::empty_logger
    end

    it 'should execute the command' do
      expect(subject).to receive(:fetch).with('list-machines', '-l')

      subject.fetch_machines cluster
    end

    it 'should parse the result of the command' do
      allow(runner).to receive(:output).and_return('output')
      expect(subject).to receive(:parse_machines).with('output', cluster).once

      subject.fetch_machines cluster
    end

    it 'should return true if the command was successful' do
      expect(subject).to receive(:fetch).and_return(true)

      expect(subject.fetch_machines cluster).to be true
    end

    it 'should return false if the command was unsuccessful' do
      expect(subject).to receive(:fetch).and_return(false)

      expect(subject.fetch_machines cluster).to be false
    end

    it 'should merge result into the passed hash' do
      allow(subject).to receive(:parse_machines) do
        subject.machines.add_or_find({a: 1})
      end

      passed_hash = Fleet::ItemSet.new([{b: 2}])
      subject.fetch_machines passed_hash
      expect(passed_hash).to include({a: 1}, {b: 2})
    end
  end

  describe '#fetch_units' do
    let(:controller) { double('controller').as_null_object }

    before :each do
      allow(subject).to receive(:fetch)
                        .with('list-units', '-l')
                        .and_yield('output')
      Fleetctl.config logger: Support::empty_logger
    end

    it 'should execute the command' do
      expect(subject).to receive(:fetch).with('list-units', '-l')

      subject.fetch_units controller
    end

    it 'should parse the result of the command' do
      allow(runner).to receive(:output).and_return('output')
      expect(subject).to receive(:parse_units).with('output', controller).once

      subject.fetch_units controller
    end

    it 'should return true if the command was successful' do
      expect(subject).to receive(:fetch).and_return(true)

      expect(subject.fetch_units controller).to be true
    end

    it 'should return false if the command was unsuccessful' do
      expect(subject).to receive(:fetch).and_return(false)

      expect(subject.fetch_units controller).to be false
    end

    it 'should merge result into the passed hash' do
      allow(subject).to receive(:parse_units) do
        subject.units.add_or_find({a: 1})
      end

      controller.units = Fleet::ItemSet.new([{b: 2}])
      subject.fetch_units controller
      expect(controller.units).to include({a: 1}, {b: 2})
    end
  end

  describe '#parse_machines' do
    let(:cluster) { double('cluster').as_null_object }
    let(:raw_table) { 'table' }
    let(:machines_parsed) { [
        {machine: '4ce83dd1b1c94d67af00ba264499b6d0', ip: '10.240.190.254', metadata: nil},
        {machine: 'aafdf1ed253844108ba4f10d75922f2b', ip: '10.240.51.254', metadata: nil},
        {machine: 'd44af62acaf347b4a1f26eeb0393fca3', ip: '10.240.159.164', metadata: nil}
    ] }
    let(:machines_expected) { [
        {id: '4ce83dd1b1c94d67af00ba264499b6d0', ip: '10.240.190.254', metadata: nil, cluster: cluster},
        {id: 'aafdf1ed253844108ba4f10d75922f2b', ip: '10.240.51.254', metadata: nil, cluster: cluster},
        {id: 'd44af62acaf347b4a1f26eeb0393fca3', ip: '10.240.159.164', metadata: nil, cluster: cluster}
    ] }

    before :each do
      allow(Fleetctl::TableParser).to receive(:parse)
                                      .and_return(machines_parsed)
    end

    it 'should try to add each machine to the cluster' do
      expect(subject.machines).to receive(:add_or_find)
                                  .exactly(machines_parsed.length)
                                  .times

      subject.parse_machines raw_table, cluster
    end

    it 'should make sure that each machine is valid' do
      expect(subject.machines).to receive(:add_or_find)
                                  .with Fleet::Machine.new(machines_expected[0])
      expect(subject.machines).to receive(:add_or_find)
                                  .with Fleet::Machine.new(machines_expected[1])
      expect(subject.machines).to receive(:add_or_find)
                                  .with Fleet::Machine.new(machines_expected[2])

      subject.parse_machines raw_table, cluster
    end

  end
end