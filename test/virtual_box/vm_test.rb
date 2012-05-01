require File.expand_path('../helper.rb', File.dirname(__FILE__))

describe VirtualBox::Vm do 
  describe 'anonymous' do
    before do
      @vm = VirtualBox::Vm.new
    end
    
    it 'should receive a name' do
      @vm.name.wont_be_nil
    end
    
    it 'should receive an UID' do
      @vm.uid.wont_be_nil
    end
    
    it 'should be unregistered' do
      @vm.wont_be :registered?
    end
    
    describe 'registered' do
      before do
        @vm.register
      end
      
      after do
        @vm.unregister
      end
      
      it 'should know it is registered' do
        @vm.must_be :registered?
      end
      
      it 'should show up on the list of registered VM UIDs' do
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
        
        it 'should show up on the list of started VM UIDs' do
          uids = VirtualBox::Vm.started_uids
          uids.must_include @vm.uid
        end
      end
    end
  end
end
