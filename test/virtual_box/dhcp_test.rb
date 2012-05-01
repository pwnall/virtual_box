require File.expand_path('../helper.rb', File.dirname(__FILE__))

describe VirtualBox::Dhcp do
  describe 'ip 192.168.0.1' do
    before do
      @dhcp = VirtualBox::Dhcp.new :ip => '192.168.0.1'
    end
    it 'has a default netmask' do
      @dhcp.netmask.must_equal '255.255.255.0'
    end
    it 'computes the IP block start' do
      @dhcp.start_ip.must_equal '192.168.0.2'
    end
    it 'computes the IP block end' do
      @dhcp.end_ip.must_equal '192.168.0.254'
    end
  end
  
  describe 'startip 192.168.0.64' do
    before do
      @dhcp = VirtualBox::Dhcp.new :start_ip => '192.168.0.64'
    end    
    it 'computes the server IP' do
      @dhcp.ip.must_equal '192.168.0.1'
    end
  end
  
  describe 'random rule' do
    before do
      @dhcp = VirtualBox::Dhcp.new :net_name => 'rbxvbox0', :ip => '10.1.0.1'
    end
    
    it 'is not live' do
      @dhcp.wont_be :live?
    end
    
    describe 'after being added' do
      before { @dhcp.add }
      after { @dhcp.remove }
      
      it 'is live' do
        @dhcp.must_be :live?
      end
      
      it 'shows up on the list of live servers' do
        servers = VirtualBox::Dhcp.all
        dhcp = servers.find { |s| s.net_name == @dhcp.net_name }
        dhcp.to_hash.must_equal @dhcp.to_hash
      end
    end
  end
end
