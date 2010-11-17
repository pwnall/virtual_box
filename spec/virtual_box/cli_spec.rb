require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe 'CLI' do
  describe 'run_command' do
    describe 'with hello world echo' do
      before(:all) do
        @result = VirtualBox.run_command(['echo', 'Hello'])
      end
      
      it 'should report successful completion' do
        @result.status.should == 0
      end
      
      it 'should return echo output' do
        @result.output.should == "Hello\n"
      end
    end
    
    describe 'with inline ruby script' do
      before(:all) do
        @result = VirtualBox.run_command(['ruby', '-e', 'print "Hi"; exit 1'])
      end
      
      it 'should return echo output' do
        @result.output.should == 'Hi'
      end
      
      it 'should report exit code 1' do
        @result.status.should == 1
      end
    end
  end
end
