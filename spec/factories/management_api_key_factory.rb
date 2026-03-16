# frozen_string_literal: true

FactoryBot.define do
  factory :management_api_key do
    association :user, factory: [:user, :admin]
    sequence(:name) { |n| "Management Key #{n}" }

    trait :revoked do
      revoked_at { Time.current }
    end
  end
end
