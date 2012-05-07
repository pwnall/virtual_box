require File.expand_path('../helper.rb', File.dirname(__FILE__))

describe VirtualBox::Vm do 
  describe 'anonymous' do
    before do
      @vm = VirtualBox::Vm.new
    end
    
    it 'receives a name' do
      @vm.name.wont_be_nil
    end
    
    it 'receives an UID' do
      @vm.uid.wont_be_nil
    end
    
    it 'is unregistered' do
      @vm.wont_be :registered?
    end
    
    describe '#register' do
      before do
        @vm.register
      end
      
      after do
        @vm.unregister
      end
      
      it 'knows it is registered' do
        @vm.must_be :registered?
      end
      
      it 'shows up on the list of registered VM UIDs' do
        uids = VirtualBox::Vm.registered_uids
        uids.must_include @vm.uid
      end
      
      it 'is not live' do
        @vm.live?.must_equal false
      end
      
      describe '#stop' do
        it "doesn't crash" do
          @vm.stop
          @vm.live?.must_equal false
        end
      end
      
      describe '#start' do
        before do
          @vm.start
        end        
        after do
          @vm.stop
        end
        
        it 'shows up on the list of started VM UIDs' do
          uids = VirtualBox::Vm.started_uids
          uids.must_include @vm.uid
        end

        it 'is live' do
          @vm.live?.must_equal true
        end
        
        describe '#stop' do
          before do
            @vm.stop
          end
          
          it 'is no longer live' do
            @vm.live?.must_equal false
          end
        end
      end
    end
  end
end
