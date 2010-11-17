describe 'Nic' do 
  describe 'NAT card and virtual card' do
    before do            
      @vm = VirtualBox::Vm.new
      @vm.nics[0] = VirtualBox::Nic.new :mode => :bridged, :chip => :amd,
           :net_id => 'eth0', :mac => 'aabbccddeeff'
      @vm.nics[2] = VirtualBox::Nic.new :mode => :virtual, :chip => :virtual,
           :net_id => 'rbx00'
      @vm.register
    end
    
    after do
      @vm.unregister
    end
    
    it 'should push/pull specs correctly' do
      vm = VirtualBox::Vm.new :uid => @vm.uid
      vm.pull_config
      vm.nics.map { |nic| nic.to_hash }.should ==
          @vm.nics.map { |nic| nic.to_hash }
    end
  end
end
