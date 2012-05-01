# TODO(pwnall): documentation for the top-level VirtualBox module
module VirtualBox
  
end

require 'hashie/mash'
require 'uuid'

require 'virtual_box/board.rb'
require 'virtual_box/cli.rb'
require 'virtual_box/dhcp.rb'
require 'virtual_box/disk.rb'
require 'virtual_box/io_bus.rb'
require 'virtual_box/net.rb'
require 'virtual_box/nic.rb'
require 'virtual_box/version.rb'
require 'virtual_box/vm.rb'
