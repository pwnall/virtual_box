describe 'VirtualBox' do
  before do
    iso_path = 'test/fixtures/tinycore/remix.iso'
    net = VirtualBox::Net.new(:ip => '192.168.166.6')
    vm = VirtualBox::Vm.new(:board => { :ram => 128, :cpus => 1 },
        :io_buses => [{ :bus => :ide, :disks => [{ :path => iso_path}]}],
        :nics => { :mode => :host, :chip => :virtual }).register
  end
end
