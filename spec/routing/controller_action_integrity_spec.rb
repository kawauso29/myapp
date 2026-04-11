require "rails_helper"

RSpec.describe "Controller and route integrity" do
  let(:app_routes) do
    Rails.application.routes.routes.filter_map do |route|
      defaults = route.defaults
      controller = defaults[:controller]
      action = defaults[:action]

      next if controller.blank? || action.blank?
      next if controller.start_with?("rails/")

      {
        path: route.path.spec.to_s,
        verb: route.verb&.source.to_s,
        controller: controller,
        action: action.to_s
      }
    end
  end

  it "maps every route to an existing controller action" do
    errors = []

    app_routes.each do |route|
      controller_class = "#{route[:controller]}_controller".camelize.safe_constantize

      if controller_class.nil?
        errors << "Missing controller: #{route[:controller]} for #{route[:verb]} #{route[:path]}"
        next
      end

      next if controller_class.action_methods.include?(route[:action])

      errors << "Missing action: #{controller_class.name}##{route[:action]} for #{route[:verb]} #{route[:path]}"
    end

    expect(errors).to be_empty, errors.join("\n")
  end

  it "recognizes GET URLs without required path params" do
    errors = []

    app_routes.each do |route|
      next unless route[:verb].include?("GET")

      raw_path = route[:path].sub("(.:format)", "")
      next if raw_path.include?(":") || raw_path.include?("*")

      path = raw_path.presence || "/"

      recognized = Rails.application.routes.recognize_path(path, method: :get)
      next if recognized[:controller] == route[:controller] && recognized[:action] == route[:action]

      errors << "Route mismatch for GET #{path}: expected #{route[:controller]}##{route[:action]}, got #{recognized[:controller]}##{recognized[:action]}"
    rescue ActionController::RoutingError, ActionController::UnknownHttpMethod => e
      errors << "Unrecognized GET #{path}: #{e.message}"
    rescue StandardError => e
      errors << "Error checking GET #{path}: #{e.class} - #{e.message}"
    end

    expect(errors).to be_empty, errors.join("\n")
  end
end
