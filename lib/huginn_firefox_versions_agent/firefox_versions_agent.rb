module Agents
  class FirefoxVersionsAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description do
      <<-MD
      The Firefox versions Agent fetches releases information for Firefox (desktop and mobile) from `https://product-details.mozilla.org/`.
      I added this agent because with website agent, when indicator is empty for "all ok status", no event was created.

      `debug` is used to verbose mode.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "FIREFOX_AURORA": "",
            "FIREFOX_DEVEDITION": "104.0b2",
            "FIREFOX_ESR": "91.12.0esr",
            "FIREFOX_ESR_NEXT": "102.1.0esr",
            "FIREFOX_NIGHTLY": "105.0a1",
            "FIREFOX_PINEBUILD": "",
            "LAST_MERGE_DATE": "2022-07-25",
            "LAST_RELEASE_DATE": "2022-07-26",
            "LAST_SOFTFREEZE_DATE": "2022-07-21",
            "LATEST_FIREFOX_DEVEL_VERSION": "104.0b2",
            "LATEST_FIREFOX_OLDER_VERSION": "3.6.28",
            "LATEST_FIREFOX_RELEASED_DEVEL_VERSION": "104.0b2",
            "LATEST_FIREFOX_VERSION": "103.0",
            "NEXT_MERGE_DATE": "2022-08-22",
            "NEXT_RELEASE_DATE": "2022-08-23",
            "NEXT_SOFTFREEZE_DATE": "2022-08-18"
          }
    MD

    def default_options
      {
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
        'type' => 'latest',
        'changes_only' => 'true'
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :debug, type: :boolean
    form_configurable :type, type: :array, values: ['latest', 'latest_esr', 'latest_nightly']

    def validate_options
      errors.add(:base, "type has invalid value: should be 'latest' 'latest_esr' 'latest_nightly'") if interpolated['type'].present? && !%w(latest latest_esr latest_nightly).include?(interpolated['type'])

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      check_versions
    end

    private

    def check_same(foo,bar,payload)
      if foo != bar
        if interpolated['debug'] == 'true'
          log "not equal, so event created!"
        end
        create_event payload: payload
      else
        if interpolated['debug'] == 'true'
          log "equal"
        end
      end
    end

    def check_versions()

      uri = URI.parse("https://product-details.mozilla.org/1.0/firefox_versions.json")
      response = Net::HTTP.get_response(uri)

      log "fetch status request status : #{response.code}"
      payload = JSON.parse(response.body)

      if interpolated['debug'] == 'true'
        log payload
      end

      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['last_status']
          if !memory['last_status'].nil?
            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil", ": null")
            last_status = JSON.parse(last_status)
            case interpolated['type']
            when "latest"
              check_same(payload['LATEST_FIREFOX_VERSION'],last_status['LATEST_FIREFOX_VERSION'],payload)
            when "latest_esr"
              check_same(payload['FIREFOX_ESR'],last_status['FIREFOX_ESR'],payload)
            when "latest_nightly"
              check_same(payload['FIREFOX_NIGHTLY'],last_status['FIREFOX_NIGHTLY'],payload)
            else
              log "Error: type has an invalid value (#{type})"
            end
          else
            create_event payload: payload
          end
          memory['last_status'] = payload.to_s
        else
          if interpolated['debug'] == 'true'
            log "equal"
          end
        end
      else
        create_event payload: payload
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload.to_s
        end
      end
    end
  end
end
