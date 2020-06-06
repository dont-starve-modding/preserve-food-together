name = "Preserve Food"
version = "1.0.0"
description = "Version " .. version .. "\n\n Use ice to temporarily preserve food in your inventory."
author = "s1m13"

api_version = 10

dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false
dst_compatible = true

icon_atlas = "preservefood.xml"
icon = "preservefood.tex"

-- forumthread = "/topic/xxx-abc/"

all_clients_require_mod = true
client_only_mod = false
server_filter_tags = { "food", "ice" }


configuration_options =
{
    {
        name = "chill_duration",
        label = "Chill duration",
        options = {
            { description = "Short", data = "low" },
            { description = "Default", data = "default" },
            { description = "Long", data = "high" },
        },
        default = "default"
    },
    {
        name = "chill_wetness",
        label = "Wetness after chilling",
        options = {
            { description = "Low", data = "low" },
            { description = "Default", data = "default" },
            { description = "High", data = "high" },
        },
        default = "default"
    }    
}
