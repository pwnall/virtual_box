describe 'Machine' do 
  describe 'os_types' do
    before do
      @types = VirtualBox::Machine.os_types
    end
    it 'should map linux 2.6' do
      @types.should include(:linux26)
    end
    
    it 'should include linux 2.6 ID' do
      @types.should include('linux26')
      @types.should include('Linux26')
    end

    it 'should include linux 2.6 description' do
      @types.should include('Linux 2.6')
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
      old_specs = @vm.specs.to_hash
      
      @vm.specs.reset
      @vm.pull_config
      @vm.specs.to_hash.should == old_specs
    end
  end
end
