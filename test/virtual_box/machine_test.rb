require File.expand_path('../helper.rb', File.dirname(__FILE__))

describe 'Machine' do 
  describe 'os_types' do
    before do
      @types = VirtualBox::Machine.os_types
    end
    it 'should map linux 2.6' do
      @types.must_include :linux26
    end
    
    it 'should include linux 2.6 ID' do
      @types.must_include 'linux26'
      @types.must_include 'Linux26'
    end

    it 'should include linux 2.6 description' do
      @types.must_include 'Linux 2.6'
    end
  end
  
  describe 'non-standard settings' do
    before do
      machine = VirtualBox::Machine.new :os => :ubuntu, :ram => 768,
          :cpus => 2, :video_ram => 16, :boot_order => [:dvd, :net, :disk]
    
      @vm = VirtualBox::Vm.new :specs => machine
      @vm.register
    end
    after do
      @vm.unregister
    end
    
    it 'should push/pull specs correctly' do
      vm = VirtualBox::Vm.new :uid => @vm.uid
      
      vm.pull_config
      vm.specs.to_hash.must_equal @vm.specs.to_hash
    end
  end
end
