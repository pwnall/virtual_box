require File.expand_path('../helper.rb', File.dirname(__FILE__))

describe VirtualBox::Net do
  describe 'host_nics' do
    let(:nics) { VirtualBox::Net.host_nics }
    
    it 'has at least 1 card' do
      nics.length.must_be :>=, 1
    end

    describe 'first card' do
      let(:card) { nics.first }
      
      it 'has a device name' do
        card[:name].wont_be_nil
      end
      
      it 'has a MAC' do
        card[:mac].wont_be_nil
      end
      
      it 'has its device name show up in ifconfig' do
        `ifconfig -a`.must_include card[:name]
      end
    end
  end

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
        @net.name.wont_be_nil
        `ifconfig -a`.must_include @net.name
      end
      
      it 'has a VirtualBox network name' do
        @net.vbox_name.wont_be_nil
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
        @net.name.wont_be_nil
        `ifconfig -a`.must_include @net.name
      end
      
      it 'shows up on the list of live networks' do
        networks = VirtualBox::Net.all
        network = networks.find { |n| n.name == @net.name }
        network.to_hash.must_equal @net.to_hash
      end      
    end
  end

  describe 'with a dhcp server' do
    before do
      @net = VirtualBox::Net.new :dhcp => { :start_ip => '192.168.166.166' }
    end
    
    it 'is not live' do
      @net.wont_be :live?
    end
    
    it 'has a DHCP server' do
      @net.dhcp.wont_be_nil
    end
    
    describe 'after adding to VirtualBox' do
      before { @net.add }
      after { @net.remove }
      
      it 'is live' do
        @net.must_be :live?
      end
      
      it 'has an interface name that shows up in the ifconfig output' do
        @net.name.wont_be_nil
        `ifconfig -a`.must_include @net.name
      end
      
      it 'shows up on the list of live networks' do
        VirtualBox::Net.named(@net.name).to_hash.must_equal @net.to_hash
      end      
    end
  end
end
