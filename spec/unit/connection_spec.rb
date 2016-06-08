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
        ::Devise.ldap_auth_username_builder = Proc.new() {|attribute, login, ldap| "#{login}" }

        options = {:login => @admin.email, :ldap_auth_username_builder => Proc.new() {|attribute, login, ldap| "#{attribute}=#{login},#{ldap.base}"}, :admin => true}
        connection = Devise::LDAP::Connection.new(options)

        myHashLDAP = Net::LDAP::Entry.new(Net::BER::BerIdentifiedString.new("example.admin@test.com,ou=people,dc=test,dc=com"))
        myHashLDAP["memberof"] = Net::BER::BerIdentifiedArray.new([Net::BER::BerIdentifiedString.new("cn=admins,ou=groups,dc=test,dc=com")])
        search_result = [myHashLDAP]

        group_checking_ldap = double('group_checking_ldap')
        allow(::Devise::LDAP::Connection).to receive(:admin).and_return(group_checking_ldap)
        group_checking_ldap.should_receive(:search).with(hash_including(:base => "dc=test,dc=com", :filter => an_instance_of(Net::LDAP::Filter), :return_result => true, :attributes => array_including(["memberof"]))).and_return(search_result)
        assert_equal true, connection.in_group?(@group_name)
        group_checking_ldap.should_receive(:search).with(hash_including(:base => "dc=test,dc=com", :filter => an_instance_of(Net::LDAP::Filter), :return_result => true, :attributes => array_including(["memberof"]))).and_return([])
        assert_equal nil, connection.in_group?('cn=superuser,ou=groups,dc=test,dc=com')
      end
    end
  end
end
