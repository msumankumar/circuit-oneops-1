require File.expand_path('../../libraries/network_security_group.rb', __FILE__)
require File.expand_path('../../../azure_base/libraries/logger.rb', __FILE__)
require File.expand_path('../../../azure_base/libraries/utils.rb', __FILE__)
require File.expand_path('../../../azure/libraries/resource_group.rb', __FILE__)

# set the proxy if it exists as a cloud var
Utils.set_proxy(node['workorder']['payLoad']['OO_CLOUD_VARS'])

# get all necessary info from node
cloud_name = node['workorder']['cloud']['ciName']
compute_service = node['workorder']['services']['compute'][cloud_name]['ciAttributes']
credentials = {
    tenant_id: compute_service['tenant_id'],
    client_secret: compute_service['client_secret'],
    client_id: compute_service['client_id'],
    subscription_id: compute_service['subscription']
}

location = compute_service[:location]
rg_service = AzureResources::ResourceGroup.new(compute_service)
nsg_service = AzureNetwork::NetworkSecurityGroup.new(credentials)

sec_rules = []
resource_group_name = nil
network_security_group_name = nil

is_new_cloud = Utils.is_new_cloud(node)

if is_new_cloud
  resource_group_name = Utils.get_nsg_rg_name(location)

  all_nsgs_in_rg = nil
  matched_nsgs = []
  pack_name = Utils.get_pack_name(node)

  rg_exists = rg_service.check_existence(resource_group_name)

  if rg_exists
    all_nsgs_in_rg = nsg_service.list_security_groups(resource_group_name)
    unless all_nsgs_in_rg.empty?
      matched_nsgs = nsg_service.get_matching_nsgs(all_nsgs_in_rg, pack_name)
    end
  else
    rg_service.add(resource_group_name, location)
  end

  network_security_group_name = Utils.get_nsg_name(node)

  sec_rules = nsg_service.get_sec_rules(node, network_security_group_name, resource_group_name)

  unless matched_nsgs.empty?
    matched_nsg_id = nsg_service.match_nsg_rules(matched_nsgs, sec_rules)
    unless matched_nsg_id.nil?
      node.set['updated_nsg_id'] = matched_nsg_id
      return
    end
  end
else
  ns_path_parts = node['workorder']['rfcCi']['nsPath'].split('/')
  org = ns_path_parts[1]
  assembly = ns_path_parts[2]
  environment = ns_path_parts[3]
  platform_ci_id = node['workorder']['box']['ciId']

  network_security_group_name = node[:name]

  # Get resource group name
  resource_group_name = AzureResources::ResourceGroup.get_name(org, assembly, platform_ci_id, environment, location)

  sec_rules = nsg_service.get_sec_rules(node, network_security_group_name, resource_group_name)
end

parameters = Fog::Network::AzureRM::NetworkSecurityGroup.new
parameters.location = location
parameters.security_rules = sec_rules

nsg_result = nsg_service.create_update(resource_group_name, network_security_group_name, parameters)
# send the name of NSG to compute workorder
puts "***RESULT:net_sec_group_id=#{nsg_result.id}"
node.set['updated_nsg_id'] = nsg_result.id

if !nsg_result.nil?
  Chef::Log.info("The network security group has been created\n\rid: '#{nsg_result.id}'\n\r'#{nsg_result.location}'\n\r'#{nsg_result.name}'\n\r")
else
  raise 'Error creating network security group'
end
