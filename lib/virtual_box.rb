# TODO(pwnall): documentation for the top-level VirtualBox module
module VirtualBox
  
end

require 'posix/spawn'
require 'uuid'

require 'virtual_box/cli.rb'
require 'virtual_box/error.rb'
require 'virtual_box/version.rb'

require 'virtual_box/vm.rb'
require 'virtual_box/vm/board.rb'
require 'virtual_box/vm/disk.rb'
require 'virtual_box/vm/io_bus.rb'
require 'virtual_box/vm/nic.rb'

require 'virtual_box/net.rb'
require 'virtual_box/net/dhcp.rb'
