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
    
    describe 'registered' do
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
      
      describe 'started' do
        before do
          @vm.start
        end        
        after do
          @vm.stop
          sleep 0.5  # VirtualBox will barf if we unregister the VM right away.
        end
        
        it 'shows up on the list of started VM UIDs' do
          uids = VirtualBox::Vm.started_uids
          uids.must_include @vm.uid
        end
      end
    end
  end
end
