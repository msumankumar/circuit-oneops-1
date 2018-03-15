require 'chef'
require 'fog/azurerm'

Dir.glob('/opt/oneops/inductor/circuit-oneops-1/components/cookbooks/azure_base/libraries/*.rb') do |lib|
  require lib
end
require '/opt/oneops/inductor/circuit-oneops-1/components/cookbooks/azuresecgroup/libraries/network_security_group.rb'

RSpec.configure do |c|
  is_new_cloud = Utils.is_new_cloud($node)
  c.filter_run_excluding :new_cloud => true if is_new_cloud
end
describe 'Azure Security Group', :new_cloud => true do
  before(:each) do
    @spec_utils = AzureSpecUtils.new($node)
  end

  context 'Security Group' do
    it 'should not exist' do
      nsgclient = AzureNetwork::NetworkSecurityGroup.new(@spec_utils.get_azure_creds)

      rginfo = @spec_utils.get_resource_group_name
      nsgname = $node['name']

      exists = nsgclient.check_network_security_group_exists(rginfo, nsgname)
      expect(exists).to eq(false)
    end
  end
end
