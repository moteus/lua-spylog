local SECOND = 1
local MINUTE = 60 * SECOND
local HOUR   = 60 * MINUTE
local DAY    = 24 * HOUR

JAIL{"fail-access";
  enabled  = false;
  filter   = {"rdp-fail-access", "fusionpbx-fail-access", "radmin-fail-access"};
  findtime = 5 * MINUTE;
  maxretry = 4;
  bantime  = 10 * MINUTE + 28 * SECOND;
  action   = "ipsec";
}

JAIL{"rdp-bad-user-access";
  enabled  = false;
  filter   = "rdp-fail-access";
  findtime = 5 * MINUTE;
  maxretry = 1;
  bantime  = 1 * DAY + 10 * MINUTE + 28 * SECOND;
  action   = "ipsec";
  cfilter  = {"list",
    type    = "allow",
    capture = "user",
    nocase  = true,
    filter  = {
      "administrator";
      "guest";
      "user";
      "root";
    };
  };
}
