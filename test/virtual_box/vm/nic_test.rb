require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe VirtualBox::Vm::Nic do 
  describe 'host_nics' do
    let(:nics) { VirtualBox::Vm::Nic.host_nics }
    
    it 'should have at least 1 card' do
      nics.length.must_be :>=, 1
    end

    describe 'first card' do
      let(:card) { nics.first }
      
      it 'should have an interface ID' do
        card[:id].wont_be_nil
      end
      
      it 'should have a  MAC' do
        card[:mac].wont_be_nil
      end
    end
  end
  
  describe 'NAT card and virtual card' do
    before do            
      @vm = VirtualBox::Vm.new :nics => [
        { :mode => :bridged, :chip => :amd,
          :net_name => VirtualBox::Vm::Nic.host_nics.first[:id],
          :mac => 'aabbccddeeff' },
        { :port => 2, :mode => :virtual, :chip => :virtual,
          :net_name => 'rbx00' }
      ]
      @vm.register
    end
    
    after do
      @vm.unregister
    end
    
    it 'should skip NIC 1' do
      @vm.nics[1].must_be_nil
    end
    
    it 'should push/pull specs correctly' do
      vm = VirtualBox::Vm.new :uid => @vm.uid
      vm.pull_config
      vm.to_hash[:nics].must_equal @vm.to_hash[:nics]
    end
  end
end
