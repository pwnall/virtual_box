require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe VirtualBox::Vm::Nic do 
  describe 'NAT card and virtual card' do
    before do            
      @vm = VirtualBox::Vm.new :nics => [
        { :mode => :bridged, :chip => :amd,
          :net_name => VirtualBox::Net.host_nics.first[:name],
          :mac => 'aabbccddeeff' },
        { :port => 2, :mode => :virtual, :chip => :virtual,
          :net_name => 'rbx00' }
      ]
      @vm.register
    end
    
    after do
      @vm.unregister
    end
    
    it 'skips NIC 1' do
      @vm.nics[1].must_be_nil
    end
    
    it 'pushes/pulls specs correctly' do
      vm = VirtualBox::Vm.new :uid => @vm.uid
      vm.pull_config
      vm.to_hash[:nics].must_equal @vm.to_hash[:nics]
    end
  end
end
