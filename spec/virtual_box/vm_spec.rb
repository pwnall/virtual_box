describe 'VM' do 
  describe 'anonymous' do
    before do
      @vm = VirtualBox::Vm.new
    end
    
    it 'should receive a name' do
      @vm.name.should_not be_nil
    end
    
    it 'should receive an UID' do
      @vm.uid.should_not be_nil
    end
    
    it 'should be unregistered' do
      @vm.should_not be_registered
    end
    
    describe 'registered' do
      before do
        @vm.register
      end
      
      after do
        @vm.unregister
      end
      
      it 'should know it is registered' do
        @vm.should be_registered
      end
      
      it 'should show up on the list of registered VM UIDs' do
        uids = VirtualBox::Vm.registered_uids
        uids.should include(@vm.uid)
      end
      
      describe 'started' do
        before do
          @vm.start
        end        
        after do
          @vm.stop
          sleep 0.5
        end
        
        it 'should show up on the list of started VM UIDs' do
          uids = VirtualBox::Vm.started_uids
          uids.should include(@vm.uid)
        end
      end
    end
  end
end
