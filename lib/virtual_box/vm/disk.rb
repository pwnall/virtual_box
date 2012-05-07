module VirtualBox

class Vm

# Descriptor for a VirtualBox hard-disk or DVD image.
class Disk
  # Path to the file storing this disk image.
  #
  # @return [String]
  attr_accessor :file
  
  # The format of this disk image.
  #
  # The recognized formats are :raw, :vdi, :vmdk, and :vhd.
  # @return [Symbol]
  attr_accessor :format
  
  # The type of media that the image represents.
  #
  # The recognized types are :disk and :dvd.
  # @return [Symbol]
  attr_accessor :media
  
  undef :format
  def format
    @format ||= self.class.guess_image_format file
  end

  undef :media
  def media
    @media ||= self.class.guess_media_type file
  end
  
  # Creates an image descriptor with the given attributes.
  #
  # @param [Hash<Symbol, Object>] options ActiveRecord-style initial values for
  #     attributes; can be used together with Disk#to_hash to save and restore
  def initialize(options)
    options.each { |k, v| self.send :"#{k}=", v }
    self.file = File.expand_path file
  end

  # Attaches this disk to a virtual machine.
  #
  # @param [VirtualBox::Vm] vm the VM that this image will be attached to
  # @param [VirtualBox::Vm::IoBus] io_bus the IO controller that this disk will
  #                                       be attached to
  # @param [Integer] port the IO bus port this disk will be connected to
  # @param [Integer] device number indicating the device's ordering on its port
  # @return [VirtualBox::Vm::Disk] self, for easy call chaining
  def add_to(vm, io_bus, port, device)
    media_arg = case media
    when :disk
      'hdd'
    when :dvd
      'dvddrive'
    end
    VirtualBox.run_command! ['VBoxManage', '--nologo', 'storageattach',
        vm.uid, '--storagectl', io_bus.name, '--port', port.to_s,
        '--device', device.to_s, '--type', media_arg, '--medium', file]
    self
  end
  
  # Creates a new image descriptor based on the given attributes.
  #
  # @param Hash<Symbol, Object> options ActiveRecord-style initial values for
  #     attributes; can be used together with Disk#to_hash to save and restore
  def to_hash
    { :file => file, :format => format, :media => media }
  end
  
  # Creates a VirtualBox disk image.
  #
  # @param [Hash] options one or many of the options documented below
  # @option options [String] file path to the file that will hold the disk image
  # @option options [Integer] size the image size, in bytes
  # @option options [Symbol] format the image format; if not provided, an
  #     intelligent guess is made, based on the file extension
  # @option options [Boolean] prealloc unless explicitly set to true, the image
  #     file will grow in size as the disk's blocks are used
  #
  # @return [VirtualBox::Vm::Disk] a Disk describing the image that was created
  def self.create(options)
    path = options[:file]
    format = options[:format] || guess_image_format(path)
    size_mb = (options[:size] / (1024 * 1024)).to_i
    memo = options[:memo] || 'Created with the virtual_box RubyGem'
    variant = options[:prealloc] ? 'Fixed' : 'Standard'
    
    VirtualBox.run_command! ['VBoxManage', '--nologo', 'createhd',
        '--filename', path, '--size', size_mb.to_s, '--format', format.to_s,
        '--variant', variant]
    new :file => path, :format => format, :media => :disk
  end
  
  # Removes the image file backing this disk.
  #
  # The method name is drop, as in "DROP TABLE". It doesn't remove the disk from
  # any VM, it just removes the file.
  # @return [VirtualBox::Vm::Disk] self, for easy call chaining
  def drop
    File.unlink @file if File.exist?(@file)
    self
  end
  
  # Disk image format based on the extension in the file name.
  def self.guess_image_format(image_file)
    parts = File.basename(image_file).split('.')
    if parts.length >= 2
      case parts.last
      when 'vdi'
        :vdi
      when 'vmdk'
        :vmdk
      when 'vhd'
        :vhd
      when 'iso'
        :raw
      else
        :vdi
      end
    else
      :vdi
    end
  end
  
  # Disk media type on the extension in the file name.
  def self.guess_media_type(image_file)
    parts = File.basename(image_file).split('.')
    if parts.length >= 2
      case parts.last
      when 'iso'
        :dvd
      else
        :disk
      end
    else
      :disk
    end
  end
end  # class VirtualBox::Vm::Disk

end  # class VirtualBox::Vm

end  # namespace VirtualBox
