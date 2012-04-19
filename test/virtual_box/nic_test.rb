require File.expand_path('../helper.rb', File.dirname(__FILE__))

describe 'Nic' do 
  describe 'host_nics' do
    let(:nics) { VirtualBox::Nic.host_nics }
    
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
      @vm = VirtualBox::Vm.new
      @vm.nics[0] = VirtualBox::Nic.new :mode => :bridged, :chip => :amd,
           :net_id => VirtualBox::Nic.host_nics.first[:id],
           :mac => 'aabbccddeeff'
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
      vm.nics.map { |nic| nic.to_hash }.
              must_equal @vm.nics.map { |nic| nic.to_hash }
    end
  end
end
