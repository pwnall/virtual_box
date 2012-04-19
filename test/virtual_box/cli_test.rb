require File.expand_path('../helper.rb', File.dirname(__FILE__))

describe 'CLI' do
  describe 'run_command' do
    describe 'with hello world echo' do
      before do
        @result = VirtualBox.run_command(['echo', 'Hello'])
      end
      
      it 'should report successful completion' do
        @result.status.must_equal 0
      end
      
      it 'should return echo output' do
        @result.output.must_equal "Hello\n"
      end
    end
    
    describe 'with inline ruby script' do
      before do
        @result = VirtualBox.run_command(['ruby', '-e', 'print "Hi"; exit 1'])
      end
      
      it 'should return echo output' do
        @result.output.must_equal 'Hi'
      end
      
      it 'should report exit code 1' do
        @result.status.must_equal 1
      end
    end
  end
end
