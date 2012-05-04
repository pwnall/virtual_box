require File.expand_path('../helper.rb', File.dirname(__FILE__))

describe VirtualBox::Net do
  describe 'with no arguments' do
    before { @net = VirtualBox::Net.new }
    
    it 'is not live' do
      @net.wont_be :live?
    end
    
    describe 'after adding to VirtualBox' do
      before { @net.add }
      after { @net.remove }
      
      it 'is live' do
        @net.must_be :live?
      end
      
      it 'has an IP' do
        @net.ip.wont_be_nil
      end
      
      it 'has a netmask' do
        @net.netmask.wont_be_nil
      end
      
      it 'has an interface name that shows up in the ifconfig output' do
        @net.if_name.wont_be_nil
        `ifconfig -a`.must_include @net.if_name
      end
      
      it 'has a name' do
        @net.name.wont_be_nil
      end
      
      it 'has a MAC address' do
        @net.mac.wont_be_nil
      end
    end
  end
  
  describe 'with a set ip and netmask' do
    before do
      @net = VirtualBox::Net.new :ip => '192.168.166.66',
                                  :netmask => '255.255.252.0'
    end
    
    it 'is not live' do
      @net.wont_be :live?
    end
    
    describe 'after adding to VirtualBox' do
      before { @net.add }
      after { @net.remove }
      
      it 'is live' do
        @net.must_be :live?
      end
      
      it 'has the same IP' do
        @net.ip.must_equal '192.168.166.66'
      end
      
      it 'has the same netmask' do
        @net.netmask.must_equal '255.255.252.0'
      end
      
      it 'has an interface name that shows up in the ifconfig output' do
        @net.if_name.wont_be_nil
        `ifconfig -a`.must_include @net.if_name
      end
      
      it 'shows up on the list of live networks' do
        networks = VirtualBox::Net.all
        network = networks.find { |n| n.if_name == @net.if_name }
        network.to_hash.must_equal @net.to_hash
      end      
    end
  end
end
