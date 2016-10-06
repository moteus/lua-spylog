local SECOND = 1
local MINUTE = 60 * SECOND
local HOUR   = 60 * MINUTE
local DAY    = 24 * HOUR

JAIL{"voip-auth-request";
  enabled  = false;
  filter   = {"freeswitch-auth-request"};
  findtime = 1 * MINUTE;
  maxretry = 10;
  bantime  = 24 * HOUR;
  action   = {"ipsec",  {"mail", {unban=false}}};
}

JAIL{"voip-auth-fail";
  enabled  = false;
  filter   = {"freeswitch-auth-fail"};
  findtime = 10 * MINUTE;
  maxretry = 3;
  bantime  = 24 * HOUR;
  action   = {"ipsec",  {"mail", {unban=false}}};
}

JAIL{"voip-ip-request";
  enabled  = false;
  filter   = {"freeswitch-ip-request"};
  findtime = 1 * MINUTE;
  maxretry = 1;
  bantime  = 7 * DAY;
  action   = {"ipsec",  {"mail", {unban=false}}};
}
