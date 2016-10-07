WHITE_IP{
  "192.168.1.11";
  "192.168.2.0/24";
}

FILTER{
}

JAIL{
  purge_interval = 10;

  -- Defaults for all jails
  default = {
    -- parameters to actions
    parameters = {
    };
  };
}

ACTION{
}

LOG{
  level   = "trace";
  file = {
    log_dir        = "./logs",
    log_name       = "event.log",
    max_size       = 10 * 1024 * 1024,
    close_file     = false,
    flush_interval = 1,
    reuse          = true,
  },
  zmq = "tcp://127.0.0.1:6060"
};

CONNECT{ FILTER = {
    JAIL = {
      type = 'bind';
      address = 'tcp://127.0.0.1:5555';
    };
  }
}

CONNECT{ JAIL = {
    FILTER = {
      type = 'connect';
      address = 'tcp://127.0.0.1:5555';
    };
    ACTION = {
      type = 'bind';
      address = 'tcp://127.0.0.1:5556';
    };
  }
}

CONNECT{ ACTION = {
    JAIL = {
      type = 'connect';
      address = 'tcp://127.0.0.1:5556';
    };
  }
}
