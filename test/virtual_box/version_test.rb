require File.expand_path('../helper.rb', File.dirname(__FILE__))

describe 'Version' do
  describe 'on 3.0.4 personal edition' do
    before do
      VirtualBox.reset_version_info!
      VirtualBox.expects(:run_command).once.
        returns({ :status => 0, :output => "3.0.4r50677\n" })
    end
    
    it 'reports release' do
      VirtualBox.version[:release].must_equal '3.0.4'
    end
    it 'reports revision' do
      VirtualBox.version[:svn].must_equal 50677
    end
    it 'reports personal edition' do
      VirtualBox.ose?.must_equal false
    end    
    it 'caches version info' do
      VirtualBox.version[:release].must_equal '3.0.4'
      VirtualBox.version[:svn].must_equal 50677
    end
  end
  
  describe 'on 3.2.8 open-source edition' do
    before do
      VirtualBox.reset_version_info!
      VirtualBox.expects(:run_command).once.
        returns({ :status => 0, :output => "3.2.8_OSEr64453\n" })
    end
    
    it 'reports release' do
      VirtualBox.version[:release].must_equal '3.2.8'
    end
    it 'reports revision' do
      VirtualBox.version[:svn].must_equal 64453
    end
    it 'reports open-source edition' do
      VirtualBox.ose?.must_equal true
    end    
  end
  
  describe 'on machine without VirtualBox' do
    before do
      VirtualBox.reset_version_info!
      VirtualBox.expects(:run_command).once.
                 returns({:status => 127})
    end
    
    it 'does not report a release' do
      VirtualBox.version[:release].must_equal nil
    end

    it 'raises an exception on ose' do
      lambda { 
        VirtualBox.ose?
      }.must_raise(RuntimeError)
    end
  end
  
  describe 'live' do
    before do
      VirtualBox.reset_version_info!
    end
      
    it 'reports some version' do
      VirtualBox.version[:release].wont_be :empty?
    end
  end
end
