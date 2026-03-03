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
end
