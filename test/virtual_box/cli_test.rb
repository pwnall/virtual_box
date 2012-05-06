require File.expand_path('../helper.rb', File.dirname(__FILE__))

describe 'CLI' do
  describe 'run_command' do
    describe 'with hello world echo' do
      before do
        @result = VirtualBox.run_command(['echo', 'Hello'])
      end
      
      it 'reports successful completion' do
        @result[:status].must_equal 0
      end
      
      it 'returns echo output' do
        @result[:output].must_equal "Hello\n"
      end
    end
    
    describe 'with inline ruby script' do
      before do
        @result = VirtualBox.run_command(['ruby', '-e', 'print "Hi"; exit 1'])
      end
      
      it 'returns echo output' do
        @result[:output].must_equal 'Hi'
      end
      
      it 'reports exit code 1' do
        @result[:status].must_equal 1
      end
    end
  end

  describe 'run_command!' do
    describe 'with hello world echo' do
      before do
        @output = VirtualBox.run_command!(['echo', 'Hello'])
      end
      
      it 'returns echo output' do
        @output.must_equal "Hello\n"
      end
    end
    
    describe 'with inline ruby script' do
      it 'raises VirtualBox::Error' do
        lambda {
          VirtualBox.run_command! ['ruby', '-e', 'print "Hi"; exit 1']
        }.must_raise VirtualBox::Error
      end
    end
  end
end
