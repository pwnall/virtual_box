require File.expand_path('../helper.rb', File.dirname(__FILE__))

require 'net/ssh'

describe 'VirtualBox' do
  before do
    iso_file = 'test/fixtures/tinycore/remix.iso'
    @net = VirtualBox::Net.new(:ip => '192.168.66.6',
        :netmask => '255.255.255.0',
        :dhcp => { :start_ip => '192.168.66.66' }).add

    @vm = VirtualBox::Vm.new(
        :board => { :ram => 256, :cpus => 1, :video_ram => 16,
                    :os => :linux26 },
        :io_buses => [{ :bus => :ide,
                        :disks => [{ :file => iso_file, :port => 1 }] }],
        :nics => [{ :mode => :host, :chip => :virtual,
                    :net_name => @net.name }]).register
  end

  after do
    # @vm.unregister unless @vm.nil?
    # @net.remove unless @net.nil?
  end

  describe 'after VM start' do
    before do
      @vm.start
      # Give the VM a chance to boot and generate SSH keys.
      Kernel.sleep 3
    end

    after do
      # @vm.stop unless @vm.nil?
    end

    it 'responds to a SSH connection' do
      output = nil
      1.upto(10) do |attempt|
        begin
          Net::SSH.start '192.168.66.66', 'tc', :timeout => 15,
              :global_known_hosts_file => [], :user_known_hosts_file => [],
              :paranoid => false, :password => '' do |ssh|
            output = ssh.exec!('ifconfig')
          end
          break
        rescue SystemCallError
          # The NIC is not yet registered.
          raise if attempt == 10
          sleep 1
        end
      end

      output.wont_be_nil
    end
  end
end
