describe Fleetctl::SSHable do
  class MockSSHable
    include Fleetctl::SSHable
    def ip
      @ip ||= Support::random_ipv4
    end
  end

  let(:runner) { double('runner').as_null_object }
  subject { MockSSHable.new }

  before :each do
    allow(Fleetctl::Runner::SSH).to receive(:new).and_return(runner)
  end

  it 'should execute the correct ssh command' do
    expect(Fleetctl::Runner::SSH).to receive(:new).once
                                     .with('fleetctl cat service')

    subject.ssh %w(fleetctl cat service)
  end

  it 'should execute the ssh command against the correct host:port' do
    expect(runner).to receive(:run).with(host: subject.ip,
                                         ssh_options: { port: 42 })

    subject.ssh %w(fleetctl cat service), port: 42
  end

  it 'should return the output of the command' do
    allow(runner).to receive(:output).and_return('ssh result')

    expect(subject.ssh %w(fleetctl cat service)).to eq('ssh result')
  end
end