# TODO(pwnall): documentation for the top-level VirtualBox module
module VirtualBox
  
end

require 'hashie/mash'
require 'uuid'

require 'virtual_box/cli.rb'
require 'virtual_box/version.rb'

require 'virtual_box/vm.rb'
require 'virtual_box/vm/board.rb'
require 'virtual_box/vm/disk.rb'
require 'virtual_box/vm/io_bus.rb'
require 'virtual_box/vm/nic.rb'

require 'virtual_box/dhcp.rb'
require 'virtual_box/net.rb'
