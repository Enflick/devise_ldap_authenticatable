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
        ::Devise.ldap_config = Proc.new() {{
            'host' => 'localhost',
            'port' => 3389,
            'base' => 'ou=testbase,dc=test,dc=com',
            'group_base' => 'ou=testbase,dc=test,dc=com',
            'attribute' => 'cn',
            'user_lookup_attribute' => 'mail',
            'group_lookup_attribute' => 'memberof',
            'admin_user' => 'cn=admin,dc=test,dc=com',
            'admin_password' => 'secret',
            'required_groups' => ['testgroup1', 'testgroup2']
        }}
        ::Devise.ldap_ad_group_check = true
        ::Devise.ldap_check_group_membership = true
        ::Devise.ldap_auth_username_builder = Proc.new() {|attribute, login, ldap| "#{login}"}
        connection = Devise::LDAP::Connection.new(:login => admin.email, :password => admin.password, :admin => true)
        assert_equal true, connection.in_group?('cn=admins,ou=testbase,dc=test,dc=com')
      end
    end
  end
end
