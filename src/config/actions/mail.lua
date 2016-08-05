ACTION{"mail",
  ban   = { "@spylog.actions.mail", [["SpyLog ban <HOST>" "
    Filter: <FILTER>
    Jail:   <JAIL>
    Host:   <HOST>
    <MSG>
  "]]};

  unban = { "@spylog.actions.mail", [["SpyLog unban <HOST>" "
    Filter: <FILTER>
    Jail:   <JAIL>
    Host:   <HOST>
    <MSG>
  "]]};

  options = {
    server = {
      address  = "smtp.domain.local";
      user     = "spylog@domain.local";
      password = "secret";
      -- ssl      = {verify = {"none"}};
    },

    from = {
      title    = "SpyLog Service";
      address  = "spylog@domain.local";
    },

    to = {
      title    = "Dear Admin";
      address  = "admin@domain.local";
    },
  }
};
