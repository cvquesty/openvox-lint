# frozen_string_literal: true

require 'set'

# Legacy (unstructured) top-scope facts are removed in Puppet 8 / OpenVox 8.
# Use structured facts via $facts hash instead.
#
# e.g. $osfamily       -> $facts['os']['family']
#      $fqdn           -> $facts['networking']['fqdn']
#      $ipaddress      -> $facts['networking']['ip']
#      $operatingsystem -> $facts['os']['name']
OpenvoxLint.new_check(:legacy_facts) do
  LEGACY_FACTS = %w[
    architecture augeasversion bios_release_date bios_vendor bios_version
    blockdevice_sda_model blockdevice_sda_size blockdevice_sda_vendor
    blockdevices boardmanufacturer boardproductname boardserialnumber
    chassisassettag chassistype domain facterversion filesystems fqdn
    gid hardwareisa hardwaremodel hostname id interfaces ipaddress
    ipaddress6 is_virtual kernel kernelmajversion kernelrelease
    kernelversion lsbdistcodename lsbdistdescription lsbdistid
    lsbdistrelease lsbmajdistrelease lsbminordistrelease lsbrelease
    macaddress manufacturer memoryfree memorysize memoryfree_mb
    memorysize_mb netmask network operatingsystem operatingsystemmajrelease
    operatingsystemrelease os osfamily path physicalprocessorcount
    processor0 processorcount productname ps puppetversion rubyplatform
    rubysitedir rubyversion selinux selinux_config_mode
    selinux_config_policy selinux_current_mode selinux_enforced
    selinux_policyversion serialnumber sp_boot_mode sp_boot_volume
    sp_cpu_type sp_current_processor_speed sp_l2_cache_core
    sp_l3_cache sp_local_host_name sp_machine_model sp_machine_name
    sp_number_processors sp_os_version sp_packages sp_physical_memory
    sp_platform_uuid sp_secure_vm sp_serial_number sp_smc_version_system
    sp_uptime sshdsakey sshecdsakey sshed25519key sshfp_dsa sshfp_ecdsa
    sshfp_ed25519 sshfp_rsa sshrsakey swapfree swapfree_mb swapsize
    swapsize_mb system_uptime timezone type uniqueid uptime
    uptime_days uptime_hours uptime_seconds uuid virtual
  ].freeze

  def check
    local_vars = collect_local_vars
    tokens.each do |tok|
      next unless tok.type == :VARIABLE
      # Strip leading $ and :: prefix, and any trailing : left by the
      # lexer when a variable is used as a resource title ($fact:).
      name = tok.value.sub(/^\$/, '').sub(/\A::/, '').chomp(':')
      next unless LEGACY_FACTS.include?(name)
      next if local_vars.include?(name)
      notify :warning,
        message: "legacy fact '#{name}' — use $facts['...'] structured fact instead (Puppet 8 / OpenVox 8)",
        line: tok.line, column: tok.column
    end
  end

  private

  # Collect variable names that are declared locally (class/define parameters
  # or lambda block parameters) so they are not mistaken for legacy facts.
  def collect_local_vars
    local = Set.new
    toks = tokens
    i = 0
    while i < toks.size
      case toks[i].type
      when :CLASS, :DEFINE
        # Skip to the opening LPAREN of the parameter list (stop at LBRACE)
        j = i + 1
        j += 1 while j < toks.size && toks[j].type != :LPAREN && toks[j].type != :LBRACE
        if j < toks.size && toks[j].type == :LPAREN
          depth = 1
          j += 1
          while j < toks.size && depth > 0
            case toks[j].type
            when :LPAREN then depth += 1
            when :RPAREN then depth -= 1
            when :VARIABLE then local << toks[j].value.sub(/^\$/, '').sub(/\A::/, '') if depth == 1
            end
            j += 1
          end
        end
      when :PIPE
        # Lambda parameter list: |$var1, $var2|
        j = i + 1
        while j < toks.size && toks[j].type != :PIPE
          local << toks[j].value.sub(/^\$/, '').sub(/\A::/, '') if toks[j].type == :VARIABLE
          j += 1
        end
        i = j # skip past closing PIPE
      end
      i += 1
    end
    local
  end
end
