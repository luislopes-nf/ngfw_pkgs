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
class OSLibrary::ArpsManager < Alpaca::OS::ManagerBase
  include Singleton
  
  ConfigFile = "/etc/untangle-net-alpaca/arps"
  
  def get_active
    results = []
    arp = `arp -n`.split( "\n" )
    number_of_heading_lines = 1
    arp = arp.slice( number_of_heading_lines, arp.length )
    arp.each do |entry|
      items = entry.split
      next if items.length != 5
      a = ActiveArp.new
      a.ip_address = items[0]
      a.mac_address = items[2]
      a.interface = items[4]
      results << a
    end
    return results
  end

  def register_hooks
    os["network_manager"].register_hook( -100, "arps_manager", "write_files", :hook_write_files )
  end
  
  def hook_commit
    write_files
    run_services
  end

  def hook_write_files
    static_arps = StaticArp.find( :all )
    
    cfg = []

    static_arps.each do |static_arp|
      #TODO is this the right command? Maybe add pub or temp arguments?
      cfg << "arp -s " + static_arp.hostname + " " + static_arp.hw_addr
    end
    cfg << "exit 0"
    os["override_manager"].write_file( ConfigFile, header, "\n", cfg.join( "\n" ), "\n" )
  end
 
  def hook_run_services
    ## Restart networking
    raise "Unable to reconfigure arp settings." unless run_command( "sh #{ConfigFile}" ) == 0
  end

  def header
    <<EOF
#!/bin/bash
## #{Time.new}
## Auto Generated by the Untangle Net Alpaca
## If you modify this file manually, your changes
## may be overriden

## Delete all of the existing static entries.
awk '/0x6/ { system( "arp -d " $1 ) }' /proc/net/arp || true
EOF
  end
end
