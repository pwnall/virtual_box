describe 'DHCP' do
  describe 'ip 192.168.0.1' do
    before do
      @dhcp = VirtualBox::Dhcp.new :ip => '192.168.0.1'
    end
    it 'should default the netmask' do
      @dhcp.netmask.should == '255.255.255.0'
    end
    it 'should compute the IP block start' do
      @dhcp.start_ip.should == '192.168.0.2'
    end
    it 'should compute the IP block end' do
      @dhcp.end_ip.should == '192.168.0.254'
    end
  end
  
  describe 'startip 192.168.0.64' do
    before do
      @dhcp = VirtualBox::Dhcp.new :start_ip => '192.168.0.64'
    end    
    it 'should compute the server IP' do
      @dhcp.ip.should == '192.168.0.1'
    end
  end
  
  describe 'random rule' do
    before do
      @dhcp = VirtualBox::Dhcp.new :name => 'rbx0', :ip => '10.1.0.1'
    end
    
    it 'should be unregistered' do
      @dhcp.should_not be_registered
    end
    
    describe 'registered' do
      before do
        @dhcp.register
      end
      
      after do
        @dhcp.unregister
      end
      
      it 'should know it is registered' do
        @dhcp.should be_registered
      end
      
      it 'should show up on the list of registered rules' do
        rules = VirtualBox::Dhcp.registered
        rule = rules.find { |r| r.name = @dhcp.name }
        rule.should_not be_nil
      end
    end
  end
end
