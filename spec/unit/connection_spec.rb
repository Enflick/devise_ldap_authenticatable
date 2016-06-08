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
        @admin = Factory.create(:admin)
        @group_lookup_attribute = 'memberof'
        @user_lookup_attribute = 'extensionAttribute2'
        @group_name = 'cn=admins,ou=groups,dc=test,dc=com'
        ::Devise.ldap_config = Proc.new() {{
            'host' => 'localhost',
            'port' => 3389,
            'base' => 'dc=test,dc=com',
            'group_base' => 'ou=groups,dc=test,dc=com',
            'attribute' => 'cn',
            'user_lookup_attribute' => 'extensionAttribute2',
            'group_lookup_attribute' => 'memberOf',
            'admin_user' => 'cn=admin,dc=test,dc=com',
            'admin_password' => 'secret',
            'required_groups' => ['cn=admins,ou=groups,dc=test,dc=com']
        }}
        ::Devise.ldap_ad_group_check = true
        ::Devise.ldap_check_group_membership = true
        ::Devise.ldap_auth_username_builder = Proc.new() {|attribute, login, ldap|
          "#{login}"
        }

        def mockResponse(group_lookup_attribute, user_lookup_attribute, group_name)
          filter = generate_filter(group_lookup_attribute, user_lookup_attribute, group_name)
          #TODO: Fix Byteslicing to be a regex, this is a hack to equate the two strings since they are off by one byte whch is the 40th UTF character (apparently not whitespace)
          if(filter.to_s.byteslice(1..-1) == "&(#{user_lookup_attribute}=cn=example.admin@test.com,ou=people,dc=test,dc=com)(#{group_lookup_attribute}=cn=admins,ou=groups,dc=test,dc=com))".encode('UTF-8'))
            myHashLDAP = Net::LDAP::Entry.new(Net::BER::BerIdentifiedString.new("example.admin@test.com,ou=people,dc=test,dc=com"))
            myHashLDAP["memberof"] = Net::BER::BerIdentifiedArray.new([Net::BER::BerIdentifiedString.new("cn=admins,ou=groups,dc=test,dc=com")])
            search_result = [myHashLDAP]
          end
          if !search_result.nil? && !(search_result.first[:memberOf].is_a?(Array).nil?) && search_result && search_result.first && search_result.first[:memberOf].is_a?(Array)
            true
          else
            false
          end
        end

        def generate_filter(group_lookup_attribute, user_lookup_attribute, group_name)
          options = {:login => @admin.email,
                     :ldap_auth_username_builder => Proc.new() {|attribute, login, ldap| "#{attribute}=#{login},#{ldap.base}"},
                     :admin => true}
          connection = Devise::LDAP::Connection.new(options)
          return Net::LDAP::Filter.join(
              Net::LDAP::Filter.eq(user_lookup_attribute, connection.dn),
              Net::LDAP::Filter.eq(group_lookup_attribute, group_name))
        end

        #TODO: Fix Byteslicing to be a regex, this is a hack to equate the two strings since they are off by one byte whch is the 40th UTF character (apparently not whitespace)
        assert_equal true, generate_filter(@group_lookup_attribute, @user_lookup_attribute, @group_name).to_s.byteslice(1..-1) == "&(#{@user_lookup_attribute}=cn=example.admin@test.com,ou=people,dc=test,dc=com)(#{@group_lookup_attribute}=cn=admins,ou=groups,dc=test,dc=com))".encode('UTF-8')
        assert_equal true, mockResponse(@group_lookup_attribute, @user_lookup_attribute, @group_name)
        assert_equal false, mockResponse(@group_lookup_attribute, @user_lookup_attribute, 'cn=users,ou=groups,dc=test,dc=com')
      end
    end
  end
end
