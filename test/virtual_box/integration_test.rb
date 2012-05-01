require File.expand_path('../helper.rb', File.dirname(__FILE__))

require 'net/ssh'

describe 'VirtualBox' do
  before do
    iso_file = 'test/fixtures/tinycore/remix.iso'
    @net = VirtualBox::Net.new(:ip => '192.168.66.6',
                               :netmask => '255.255.255.0').add
    @dhcp = VirtualBox::Dhcp.new(:net_name => @net.name,
                                 :start_ip => '192.168.66.66').add
    @vm = VirtualBox::Vm.new(
        :board => { :ram => 256, :cpus => 1, :video_ram => 16,
                    :os => :linux26 },
        :io_buses => [{ :bus => :ide,
                        :disks => [{ :file => iso_file, :port => 1 }] }],
        :nics => [{ :mode => :host, :chip => :virtual,
                    :net_name => @net.if_name }]).register
  end
  
  after do
    @vm.unregister unless @vm.nil?
    @dhcp.remove unless @dhcp.nil?
    @net.remove unless @net.nil?
  end
  
  describe 'after VM start' do
    before do
      @vm.start
      # Give the VM a chance to boot and generate SSH keys.
      Kernel.sleep 3
    end
    
    after do
      unless @vm.nil?
        @vm.stop
        # Let VirtualBox stop the VM, so that it can be unregistered.
        Kernel.sleep 0.5
      end
    end
    
    it 'should respond to a SSH connection' do
      output = nil
      Net::SSH.start '192.168.66.66', 'tc', :timeout => 10,
          :global_known_hosts_file => [], :user_known_hosts_file => [],
          :paranoid => false, :password => '' do |ssh|
        output = ssh.exec!('ifconfig')
      end
      
      output.wont_be_nil
    end
  end
end
