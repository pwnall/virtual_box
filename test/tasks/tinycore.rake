# Tasks that build the TinyCore ISO used by the integration test.

# Produces TinyCore spins.
#
# The implementation is heavily based on the official instructions at
# http://wiki.tinycorelinux.net/wiki:remastering
class TinyCore
  # @return [String] path to the directory holding all the information
  attr_reader :base
  # @return [String] path to the vanilla Core ISO
  attr_reader :iso
  # @return [String] path to the unpacked version of the vanilla Core ISO
  attr_reader :cd_fs
  # @return [String] path to the directory caching extensions
  attr_reader :pkg
  # Path to the directory holding the contents of our remix's extension.
  # @return [String]
  attr_reader :ext_fs
  # @return [String] path to the CPIO+GZ file-system in the unpacked Core ISO
  attr_reader :fs_cpgz

  def initialize(base_path)
    @base = base_path
    recompute_paths
  end
  
  # Computes all the working paths based on the base path. 
  def recompute_paths
    @cd_fs = File.join base, 'cd'
    @ext_fs = File.join base, 'ext'
    @pkg = File.join base, 'pkg'
    
    @iso = File.join base, 'core.iso'
    @fs_cpgz = File.join cd_fs, 'boot/core.gz'
  end
  private :recompute_paths
  
  # Ensures that the TinyCore CD file-system is unpacked somewhere.
  #
  # This method might download the core ISO, and unpack it.
  #
  # @return [String] the same path returned by #ext_fs
  def ensure_cd_fs_available
    return cd_fs if File.exist? cd_fs
    
    download_iso unless File.exist? iso
    unpack_iso
    ext_fs
  end
  
  # Downloads the core ISO.
  #
  # @raise [RuntimeError] if there's an error downloading the ISO
  # @return [TinyCore] self, for easy call chaining
  def download_iso
    FileUtils.mkdir_p base
    url = 'http://distro.ibiblio.org/tinycorelinux/4.x/x86/' +
          'release/Core-current.iso'
    download_file url, iso
    self
  end
  private :download_iso
  
  # Unpacks the core ISO.
  #
  # @raise [RuntimeError] if there's an error unpacking the ISO
  # @return [TinyCore] self, for easy call chaining
  def unpack_iso
    FileUtils.mkdir_p cd_fs
    success = Kernel.system "7z x -y -o#{cd_fs} #{iso}"
    unless success
      FileUtils.rm_rf cd_fs
      raise "ISO unpacking failed"
    end
    self
  end
  private :unpack_iso
  
  # Ensures that a TinyCore extension and its dependencies are downloaded.
  #
  # @param [String] package_name the name of the package (e.g., "openssh")
  # @return [String] the file-system path where the package was downloaded
  def ensure_package_available(package_name)
    package_file = File.join pkg, "#{package_name}.tcz"
    return package_file if File.exist?(package_file)
    
    # NOTE: The check above relies on the dependencies being installed before
    #       the package itself.
    package_deps(package_name).each do |dependency|
      ensure_package_available dependency
    end
    
    package_url = 'http://distro.ibiblio.org/tinycorelinux/4.x/x86/tcz/' +
                  "#{package_name}.tcz"
    FileUtils.mkdir_p pkg
    download_file package_url, package_file
  end
  
  # The TinyCore packages that a package directly depends on.
  #
  # This method downloads the package's .dep file, if it doesn't already exist.
  #
  # @param [String] package_name the name of the package (e.g., "openssh")
  # @return [Array<String>] names of the package's direct dependencies
  def package_deps(package_name)
    FileUtils.mkdir_p pkg
    
    info_file = File.join pkg, "#{package_name}.tcz.dep"
    unless File.exist? info_file
      info_url = 'http://distro.ibiblio.org/tinycorelinux/4.x/x86/tcz/' +
                 "#{package_name}.tcz.dep"
      download_file info_url, info_file
    end
    
    deps = []
    File.read(info_file).split.map do |dep|
      break unless /\.tcz\Z/ =~ dep
      deps << dep.sub(/\.tcz\Z/, '')
    end
    deps
  end
  private :package_deps

  # Installs a TinyCore package and its deps to the extension file-system.
  #
  # @param [String] package_name the name of the package (e.g., "openssh")
  # @raise [RuntimeError] if some package download or decompression fails
  # @return [TinyCore] the same path returned by #ext_fs
  def install_package(package_name)
    ensure_package_available package_name
    package_transitive_deps(package_name).reverse.each do |dependency|
      unpack_package dependency
    end
    ext_fs
  end
  
  # All the TinyCore packages that a package indirectly depends on.
  #
  # This method downloads the referenced .dep files, if they don't already
  # exist.
  #
  # @param [String] package_name the name of the package (e.g., "openssh")
  # @param [Hash<String, Boolean>] dependencies internal argument that tracks
  #     the dependency table as it is being built
  # @return [Array<String>] names of all the packages that the given package
  #     indirectly depends on, including itself
  def package_transitive_deps(package_name, dependencies = {})
    dependencies[package_name] = true
    package_deps(package_name).each do |dependency|
      next if dependencies.has_key? dependency
      package_transitive_deps dependency, dependencies
    end
    dependencies.keys
  end
  private :package_transitive_deps
  
  # Extracts a TinyCore package to the extension file-system.
  #
  # @param [String] package_name the name of the package (e.g., "openssh")
  # @raise [RuntimeError] if the package decompression fails
  # @return [TinyCore] self, for easy call chaining
  def unpack_package(package_name)
    package_tcz = ensure_package_available package_name
    FileUtils.mkdir_p ext_fs
    success = Kernel.system "unsquashfs -d #{ext_fs} -f -n #{package_tcz}"
    return self if success
    
    raise "TCZ unpacking failed"
  end
  private :unpack_package
  
  # Helper method for downloading a file over HTTP.
  #
  # @param [String] url the URL to download the file from
  # @param [String] file the file-system path where the file will be saved
  # @raise [RuntimeError] if there's an error downloading the file
  # @return [String] the value of the "file argument"
  def download_file(url, file)
    success = Kernel.system "curl -o #{file} #{url}"
    return file if success
    
    File.unlink file if File.exist?(file)
    raise "Download failed"
  end
  private :download_file
end

# All TinyCore files will be created here. This should be gitignored.
tinycore = TinyCore.new 'test/fixtures/tinycore'

file 'test/fixtures/tinycore/tc_ssh.iso' do
  tinycore.ensure_cd_fs_available
  tinycore.install_package 'openssh'
end

task :fixtures => 'test/fixtures/tinycore/tc_ssh.iso'
