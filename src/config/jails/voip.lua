JAIL{"voip-auth-request";
  enabled  = false;
  filter   = {"freeswitch-auth-request", "vssc-auth-request"};
  findtime = 60;
  maxretry = 10;
  bantime  = 3600 * 24;
  action   = "ipsec";
}

JAIL{"voip-auth-fail";
  enabled  = false;
  filter   = {"freeswitch-auth-fail", "vssc-auth-fail"};
  findtime = 600;
  maxretry = 3;
  bantime  = 3600 * 24;
  action   = "ipsec";
}
