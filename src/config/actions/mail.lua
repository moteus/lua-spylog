ACTION{"mail",
  on  = { "@spylog.actions.mail", [["SpyLog ban <HOST>" "
    Filter: <FILTER>
    Jail:   <JAIL>
    Host:   <HOST>
  "]]};

  off = { "@spylog.actions.mail", [["SpyLog unban <HOST>" "
    Filter: <FILTER>
    Jail:   <JAIL>
    Host:   <HOST>
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
