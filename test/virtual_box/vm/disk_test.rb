require File.expand_path('../../helper.rb', File.dirname(__FILE__))

describe VirtualBox::Vm::Disk do
  describe 'new with ISO' do
    before do
      @disk = VirtualBox::Vm::Disk.new :file => 'disk.iso'      
    end
    
    it 'should guess media type' do
      @disk.media.must_equal :dvd
    end
    
    it 'should guess image type' do
      @disk.format.must_equal :raw
    end
  end
  
  describe 'create' do
    describe '16-megabyte VMDK flexible' do
      let(:vmdk_path) { '/tmp/disk.vmdk' }
    
      before do
        File.unlink vmdk_path if File.exist?(vmdk_path)
        @disk = VirtualBox::Vm::Disk.create :file => vmdk_path,
            :prealloc => false, :size => 16 * 1024 * 1024
      end
      
      after do
        File.unlink vmdk_path if File.exist?(vmdk_path)
      end
      
      it 'should create a small file' do
        File.stat(vmdk_path).size.must_be :<, 256 * 1024
      end
      
      it 'should return a Disk pointing to the file' do
        @disk.file.must_equal vmdk_path
      end
      
      it 'should return a HDD Disk' do
        @disk.media.must_equal :disk
      end
      
      it 'should return a VMDK Disk' do
        @disk.format.must_equal :vmdk
      end
    end
    
    describe '16-megabyte preallocated' do
      let(:vdi_path) { '/tmp/disk.vdi' }
      
      before do
        File.unlink vdi_path if File.exist?(vdi_path)
        @disk = VirtualBox::Vm::Disk.create :file => vdi_path,
            :prealloc => true, :size => 16 * 1024 * 1024
      end
      
      after do
        File.unlink vdi_path if File.exist?(vdi_path)
      end
      
      it 'should create a 16-megabyte file' do
        (File.stat(vdi_path).size / (1024 * 1024)).must_equal 16
      end
      
      it 'should return a Disk pointing to the file' do
        @disk.file.must_equal vdi_path
      end
      
      it 'should return a HDD Disk' do
        @disk.media.must_equal :disk
      end
      
      it 'should return a VDI Disk' do
        @disk.format.must_equal :vdi
      end
    end
  end
  
  describe 'VM with a bunch of disks' do
    let(:disk1_file) { '/tmp/disk1.vdi' }
    let(:disk2_file) { '/tmp/disk2.vdi' }
    let(:disk3_file) { '/tmp/disk3.vdi' }
    let(:iso_file) { 'test/fixtures/tinycore/remix.iso' }
    before do
      [disk1_file, disk2_file, disk3_file].each do |file|
        File.unlink file if File.exist?(file)
        VirtualBox::Vm::Disk.create :file => file, :size => 16 * 1024 * 1024
      end
    
      @vm = VirtualBox::Vm.new :io_buses => [
        { :bus => :sata, :disks => [
            { :file => disk1_file, :port => 0, :device => 0 },
            { :file => disk2_file }
          ]},
        { :bus => :ide, :disks => [{ :file => iso_file }]},
        { :bus => :scsi, :disks => [{ :file => disk3_file }] }
      ]
      @vm.register
    end
    
    after do
      @vm.unregister
      [disk1_file, disk2_file, disk3_file].each do |file|
        File.unlink file if File.exist?(file)
      end
    end
    
    it 'should push/pull specs correctly' do
      vm = VirtualBox::Vm.new :uid => @vm.uid
      vm.pull_config
      vm.io_buses.map { |io_bus| io_bus.to_hash }.
                  must_equal @vm.io_buses.map { |io_bus| io_bus.to_hash }
    end
  end
end
