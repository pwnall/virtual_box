require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'Version' do
  describe 'on 3.0.4 personal edition' do
    before do
      VirtualBox.reset_version_info!
      VirtualBox.should_receive(:run_command).once.
        and_return(Hashie::Mash.new(:status => 0, :output => "3.0.4r50677\n"))
    end
    
    it 'should report release' do
      VirtualBox.version.release.should == '3.0.4'
    end
    it 'should report revision' do
      VirtualBox.version.svn.should == 50677
    end
    it 'should report personal edition' do
      VirtualBox.ose?.should be(false)
    end    
    it 'should cache version info' do
      VirtualBox.version.release.should == '3.0.4'
      VirtualBox.version.svn.should == 50677
    end
  end
  
  describe 'on 3.2.8 open-source edition' do
    before do
      VirtualBox.reset_version_info!
      VirtualBox.should_receive(:run_command).once.
        and_return(Hashie::Mash.new(:status => 0,
                                    :output => "3.2.8_OSEr64453\n"))
    end
    
    it 'should report release' do
      VirtualBox.version.release.should == '3.2.8'
    end
    it 'should report revision' do
      VirtualBox.version.svn.should == 64453
    end
    it 'should report open-source edition' do
      VirtualBox.ose?.should be(true)
    end    
  end
  
  describe 'on machine without VirtualBox' do
    before do
      VirtualBox.reset_version_info!
      VirtualBox.should_receive(:run_command).once.
        and_return(Hashie::Mash.new(:status => 127))
    end
    
    it 'should not report a release' do
      VirtualBox.version.release.should be(nil)
    end

    it 'should raise an exception on ose' do
      lambda { 
        VirtualBox.ose?
      }.should raise_error(RuntimeError)
    end
  end
  
  describe 'live' do
    before do
      VirtualBox.reset_version_info!
    end
      
    it 'should report some version' do
      VirtualBox.version.release.should_not be_empty
    end
  end
end
