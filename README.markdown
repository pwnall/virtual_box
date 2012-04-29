# virtual_box

This gem is a Ruby API for VirtualBox, Sun's open-source virtualization software
that supports Linux, Mac OS X, and Windows.


## Features

Currently, the gem supports the following features:
* VM creation and removal
* VM start, and stop
* Disk (VDI, VMDK, VHD) and DVD (ISO) images
* NAT, bridged, host-only and internal networking
* DHCP configuration for host-only and internal networks
* VirtualBox version detection (OSE vs. regular)


## Dependencies

The gem uses the VirtualBox CLI (command-line tools), so they must be installed
and on the system's path. The gem is developed against the documentation for
VirtualBox 4.

## Development Dependencies

Running tests relies on a few command-line tools.

On Fedora, use the following command to install the packages.

```bash
sudo yum install curl mkisofs p7zip squashfs
```

On OSX, run the following command.

```bash
brew install cdrtools curl p7zip squashfs
```


## Limitations

This gem makes some simplifying assumptions (rails people would say it is
opinionated).

* VM configuration XML file management is completely delegated to VirtualBox;
the gem assumes and enforces the invariant that all XML files map to registered
VMs


## Contributing to virtual_box
 
* Check out the latest master to make sure the feature hasn't been implemented
or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it
and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a
future version unintentionally.
* Please do not mess with the Rakefile, version, or history.


## Copyright

Copyright (c) 2010-2012 Victor Costan. See LICENSE.txt for further details.
