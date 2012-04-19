require File.expand_path('../helper.rb', File.dirname(__FILE__))

describe 'Disk' do
  describe 'new with ISO' do
    before do
      @disk = VirtualBox::Disk.new :file => 'disk.iso'      
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
        @disk = VirtualBox::Disk.create :file => vmdk_path, :prealloc => false,
            :size => 16 * 1024 * 1024
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
        @disk = VirtualBox::Disk.create :file => vdi_path, :prealloc => true,
            :size => 16 * 1024 * 1024
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
      
      it 'should return an unregistered disk' do
        @disk.wont_be :registered?
      end
      
      describe 'registered' do
        before do
          @disk.register

          images = VirtualBox::Disk.registered
          @image = images.find { |image| image.file == @disk.file }
        end
        
        after do
          @disk.unregister
        end
        
        it 'should be among disk instances' do
          @image.wont_be_nil
        end
        
        it 'should be registered' do
          @disk.wont_be :registered?
        end
      end
    end
  end
end
