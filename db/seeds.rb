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

  admin_credential = Credential.find_or_initialize_by(
    server: server,
    type: "API",
    name: "Seed API (Admin Actor)"
  )
  admin_credential.options = (admin_credential.options || {}).except("global_admin")
  admin_credential.save!

  regular_email = "user@postal.local"
  regular_password = "secretpassword"
  regular_first_name = "seededRegular"
  regular_last_name = "User"

  regular_user = User.find_or_initialize_by(email_address: regular_email)
  regular_user.assign_attributes(
    first_name: regular_first_name,
    last_name: regular_last_name,
    admin: false,
    time_zone: "UTC"
  )

  if regular_user.new_record? || !regular_user.password?
    regular_user.password = regular_password
    regular_user.password_confirmation = regular_password
  end

  regular_user.save!

  regular_membership = OrganizationUser.find_or_initialize_by(organization: organization, user: regular_user)
  regular_membership.assign_attributes(admin: false, all_servers: true)
  regular_membership.save!
end
