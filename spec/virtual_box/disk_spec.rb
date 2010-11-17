require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'Disk' do
  describe 'new with ISO' do
    before do
      @disk = VirtualBox::Disk.new :file => 'disk.iso'      
    end
    
    it 'should guess media type' do
      @disk.media.should == :dvd
    end
    
    it 'should guess image type' do
      @disk.format.should == :raw
    end
  end
  
  describe 'create' do
    describe '16-megabyte VMDK flexible' do
      let(:vmdk_path) { '/tmp/disk.vmdk' }
    
      before(:all) do
        File.unlink vmdk_path if File.exist?(vmdk_path)
        @disk = VirtualBox::Disk.create :file => vmdk_path, :prealloc => false,
            :size => 16 * 1024 * 1024
      end
      
      after(:all) do
        File.unlink vmdk_path if File.exist?(vmdk_path)
      end
      
      it 'should create a small file' do
        File.stat(vmdk_path).size.should < 256 * 1024
      end
      
      it 'should return a Disk pointing to the file' do
        @disk.file.should == vmdk_path
      end
      
      it 'should return a HDD Disk' do
        @disk.media.should == :disk
      end
      
      it 'should return a VMDK Disk' do
        @disk.format.should == :vmdk
      end
    end
    
    describe '16-megabyte preallocated' do
      let(:vdi_path) { '/tmp/disk.vdi' }
      
      before(:all) do
        File.unlink vdi_path if File.exist?(vdi_path)
        @disk = VirtualBox::Disk.create :file => vdi_path, :prealloc => true,
            :size => 16 * 1024 * 1024
      end
      
      after(:all) do
        File.unlink vdi_path if File.exist?(vdi_path)
      end
      
      it 'should create a 16-megabyte file' do
        (File.stat(vdi_path).size / (1024 * 1024)).should == 16
      end
      
      it 'should return a Disk pointing to the file' do
        @disk.file.should == vdi_path
      end
      
      it 'should return a HDD Disk' do
        @disk.media.should == :disk
      end
      
      it 'should return a VDI Disk' do
        @disk.format.should == :vdi
      end
      
      it 'should return an unregistered disk' do
        @disk.should_not be_registered
      end
      
      describe 'registered' do
        before(:all) do
          @disk.register

          images = VirtualBox::Disk.registered
          @image = images.find { |image| image.file == @disk.file }
        end
        
        after(:all) do
          @disk.unregister
        end
        
        it 'should be among disk instances' do
          @image.should_not be(nil)
        end
        
        it 'should be registered' do
          @disk.should be_registered
        end
      end
    end
  end
end
