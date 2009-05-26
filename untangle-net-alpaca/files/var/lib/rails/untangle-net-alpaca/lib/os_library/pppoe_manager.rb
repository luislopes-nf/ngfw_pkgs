#
# $HeadURL$
# Copyright (c) 2007-2008 Untangle, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
# NONINFRINGEMENT.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
class OSLibrary::PppoeManager < Alpaca::OS::ManagerBase
  include Singleton

  ## xxx presently only support one connection xxx
  ProviderName = "connection0"
  PeersFileBase = "/etc/ppp/peers/"
  PapSecretsFile = "/etc/ppp/pap-secrets"


  def register_hooks
    os["network_manager"].register_hook( -100, "pppoe_manager", "write_files", :hook_write_files )
  end
  
  def hook_write_files
    ## Find the WAN interface that is configured for PPPoE.
    ## xxx presently PPPoE is only supported on the WAN interface xxx
    conditions = [ "config_type=?",  InterfaceHelper::ConfigType::PPPOE ]
    pppoe_interfaces = Interface.find( :all, :conditions => conditions )
    
    ## No PPPoE interface is available.
    return if pppoe_interfaces.nil? || pppoe_interfaces.empty?

    secrets = {}
    pppoe_interfaces.each do |pppoe_interface|
      write_pppoe_interface( pppoe_interface, secrets )
    end
    
    secrets = secrets.map { |u,p| "\"#{u}\" * \"#{p}\"" }
    override_manager = os["override_manager"]
    override_manager.write_file( PapSecretsFile, header, "\n", secrets.join( "\n" ), "\n" )
    if ( File.exists?( PapSecretsFile ) and override_manager.writable?( PapSecretsFile ))
         File.chmod( 0600, PapSecretsFile )
    end
  end

  private
  def write_pppoe_interface( pppoe_interface, secrets )
    ## Retrieve the pppoe settings from the wan interface
    settings = pppoe_interface.current_config

    ## Verify that the settings are actually available.
    return if settings.nil? || !settings.is_a?( IntfPppoe )
    
    cfg = []

    cfg << <<EOF
#{header}
noipdefault
hide-password
noauth
persist
maxfail 0
EOF

    
    cfg << "usepeerdns" if ( settings.use_peer_dns )

    ## Use the PPPoE daemon and the current interface.
    cfg << "plugin rp-pppoe.so #{pppoe_interface.os_name}"
    
    cfg << "# PPPOE_UPLINK_INDEX=#{pppoe_interface.index}"

    ## Create a comment containing the list of "bridged" interfaces for the UVM and
    ## the name of the bridge, makes reloading the networking configuration easy.
    ## XXXX IMPORTANT DATA IN COMMENTS NOT LEGIT XXXX
    if pppoe_interface.is_bridge?
      bridge_name = OSLibrary::Debian::NetworkManager.bridge_name( pppoe_interface )
      bia = pppoe_interface.bridged_interface_array.map{ |i| i.os_name }
      cfg << "# bridge_configuration: #{bridge_name} #{bia.join(",")}"
    end

    ## Append the username
    cfg << "user \"#{settings.username}\""

    ## Append anything that is inside of the secret field for the PPPoE Configuration
    secret_field = settings.secret_field
    cfg << settings.secret_field unless secret_field.nil?

    secrets[settings.username] = settings.password
  
    ## This limits us to one connection, hardcoding to 0 for now.
    file_name = "#{PeersFileBase}#{self.class.get_provider_name( pppoe_interface )}"
    os["override_manager"].write_file( file_name, cfg.join( "\n" ), "\n" )    
  end
  
  def header
    <<EOF
## #{Time.new}
## Auto Generated by the Untangle Net Alpaca
## If you modify this file manually, your changes
## may be overriden
EOF
  end
end
