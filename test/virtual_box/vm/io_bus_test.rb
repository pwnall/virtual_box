require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe VirtualBox::Vm::IoBus do
  describe 'IDE' do
    it 'defaults to the PIIX4 chipset' do
      VirtualBox::Vm::IoBus.new(:bus => :ide).chip.must_equal :piix4
    end
    
    it 'recognizes the PIIX4 chipset' do
      VirtualBox::Vm::IoBus.new(:chip => :piix4).bus.must_equal :ide
    end
    
    it 'ie named IDE Controller by default' do
      VirtualBox::Vm::IoBus.new(:bus => :ide).name.must_equal 'IDE Controller'
    end
  end
  
  describe 'SATA' do
    it 'defaults to the AHCI chipset' do
      VirtualBox::Vm::IoBus.new(:bus => :sata).chip.must_equal :ahci
    end
    
    it 'recognizes the PIIX4 chipset' do
      VirtualBox::Vm::IoBus.new(:chip => :ahci).bus.must_equal :sata
    end

    it 'is named SATA Controller by default' do
      VirtualBox::Vm::IoBus.new(:bus => :sata).name.must_equal 'SATA Controller'
    end
  end

  describe 'VM with a bunch of IO controllers' do
    before do
      @vm = VirtualBox::Vm.new :io_buses => [
        { :bus => :ide, :name => 'Weird Name', :chip => :piix3 },
        { :bus => :sata },
        { :bus => :scsi, :chip => :lsi_logic },
        { :bus => :floppy },
      ]
      @vm.register
    end
    
    after do
      @vm.unregister
    end
    
    it 'pushes/pulls specs correctly' do
      vm = VirtualBox::Vm.new :uid => @vm.uid
      vm.pull_config
      vm.io_buses.map { |io_bus| io_bus.to_hash }.
                  must_equal @vm.io_buses.map { |io_bus| io_bus.to_hash }
    end
  end
end
