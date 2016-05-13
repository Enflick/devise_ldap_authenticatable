require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe 'Connection' do
  it 'accepts a proc for ldap_config' do
    ::Devise.ldap_config = Proc.new() { {
      'host' => 'localhost',
      'port' => 3389,
      'base' => 'ou=testbase,dc=test,dc=com',
      'attribute' => 'cn',
    } }
    connection = Devise::LDAP::Connection.new()
    expect(connection.ldap.base).to eq('ou=testbase,dc=test,dc=com')
  end

  describe 'When verifying user groups' do
    before :all do
      default_devise_settings!
      reset_ldap_server!
    end
    context 'through ldap_ad_group_check' do
      it 'should search using user_lookup_attribute and group_lookup_attribute', :focus => true do
        admin = Factory.create(:admin)
        #
        ::Devise.ldap_config = Proc.new() {{
          'host' => 'localhost',
          'port' => 3389,
          'base' => 'ou=testbase,dc=test,dc=com',
          'attribute' => 'cn',
          'user_lookup_attribute' => 'mail',
          'group_lookup_attribute' => 'memberof'
        }}
        ::Devise.ldap_ad_group_check = true
        # ::Devise.ldap_create_user = true
        # ::Devise.ldap_check_group_membership = false
        # ::Devise.ldap_check_attributes = true
        # ::Devise.ldap_use_admin_to_bind = false
        connection = Devise::LDAP::Connection.new(:login => admin.email, :password => admin.password, :admin => true)
        connection.in_group? ''

        # in_group = connection.in_group? ''
        # expect(in_group).to be_truthy
      end
    end
  end
end
