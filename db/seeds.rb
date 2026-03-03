# frozen_string_literal: true

# Test Seed Data
if Rails.env.test?
  admin_email = "admin@postal.local"
  admin_password = "secretpassword"
  admin_first_name = "seededAdmin"
  admin_last_name = "Admin"
  organization_name = "Test Org"
  organization_permalink = "test"

  admin_user = User.find_or_initialize_by(email_address: admin_email)
  admin_user.assign_attributes(
    first_name: admin_first_name,
    last_name: admin_last_name,
    admin: true,
    time_zone: "UTC"
  )

  if admin_user.new_record? || !admin_user.password?
    admin_user.password = admin_password
    admin_user.password_confirmation = admin_password
  end

  admin_user.save!

  organization = Organization.find_or_initialize_by(permalink: organization_permalink)
  organization.assign_attributes(
    name: organization_name,
    owner: admin_user,
    time_zone: "UTC"
  )
  organization.save!

  membership = OrganizationUser.find_or_initialize_by(organization: organization, user: admin_user)
  membership.assign_attributes(admin: true, all_servers: true)
  membership.save!

  server = organization.servers.find_or_initialize_by(permalink: "test-server")
  server.assign_attributes(name: "Test Server", mode: "Live")
  server.save!

  server.message_db.provisioner.provision

  scoped_credential = Credential.find_or_initialize_by(
    server: server,
    type: "API",
    name: "Seed API (Scoped)"
  )
  scoped_credential.options ||= {}
  scoped_credential.save!

  global_admin_credential = Credential.find_or_initialize_by(
    server: server,
    type: "API",
    name: "Seed API (Global Admin)"
  )
  global_admin_credential.options = (global_admin_credential.options || {}).merge("global_admin" => true)
  global_admin_credential.save!
end
