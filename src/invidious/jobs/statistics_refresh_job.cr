class Invidious::Jobs::StatisticsRefreshJob < Invidious::Jobs::BaseJob
  struct Statistics
    include JSON::Serializable

    property version : String = "2.0"
    property software : Software = Software.from_json("{}")

    struct Software
      include JSON::Serializable

      property name : String = "invidious"
      property version : String = ""
      property branch : String = ""
    end

    @[JSON::Field(key: "openRegistrations")]
    property open_registrations : Bool = true
    property usage : Usage = Usage.from_json("{}")

    struct Usage
      include JSON::Serializable
      property users : Users = Users.from_json("{}")

      struct Users
        include JSON::Serializable
        property total : Int64 = 0
        @[JSON::Field(key: "activeHalfYear")]
        property active_half_year : Int64 = 0
        @[JSON::Field(key: "activeMonth")]
        property active_month : Int64 = 0
      end
    end

    property metadata : Metadata = Metadata.from_json("{}")

    struct Metadata
      @[JSON::Field(key: "updatedAt")]
      property updated_at : Int64 = Time.utc.to_unix
      @[JSON::Field(key: "lastChannelRefreshedAt")]
      property last_channel_refreshed_at : Int64 = 0
    end

    property playback : Hash(String, Int64 | Float64) = {} of String => Int64 | Float64
  end

  private getter db : DB::Database

  def initialize(@db, @software_config : Hash(String, String))
  end

  def begin
    load_initial_stats

    loop do
      refresh_stats
      sleep 10.minute
      Fiber.yield
    end
  end

  # should only be called once at the very beginning
  private def load_initial_stats
    STATISTICS["software"] = {
      "name"    => @software_config["name"],
      "version" => @software_config["version"],
      "branch"  => @software_config["branch"],
    }
    STATISTICS["openRegistrations"] = CONFIG.registration_enabled
  end

  private def refresh_stats
    users = STATISTICS.dig("usage", "users").as(Hash(String, Int64))

    users["total"] = Invidious::Database::Statistics.count_users_total
    users["activeHalfyear"] = Invidious::Database::Statistics.count_users_active_6m
    users["activeMonth"] = Invidious::Database::Statistics.count_users_active_1m

    STATISTICS["metadata"] = {
      "updatedAt"              => Time.utc.to_unix,
      "lastChannelRefreshedAt" => Invidious::Database::Statistics.channel_last_update.try &.to_unix || 0_i64,
    }

    # Reset playback requests tracker
    STATISTICS["playback"] = {} of String => Int64 | Float64
  end
end
